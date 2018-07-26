[CmdletBinding()]
Param(
    #template path
    [Parameter(Mandatory=$True)]
    [string]$ArmTemplatePath,
    #template path
    [string]$ArmParametersPath,
    #resource group name
    [Parameter(Mandatory=$True)]
    [string]$RgName,
    #resource group name
    [string]$location = "West Europe",
    #select deployment type - can be 1 of 3: infra, msdeploy, redeploy
    [Parameter(Mandatory=$True)]
    [ValidateSet("infra", "msdeploy", "redeploy")]
    [string]$DeploymentType,
    #If set to False - SAS for files stored in storage container in same subscription will not be regenerated
    #If True - SAS will be regenerated if container is accessible (blob storage is in current subscription)
    [bool]$GenerateSas = $True
)

Import-Module "$($PSScriptRoot)\functions-module.psm1"
#region Create Params Object
# license file needs to be secure string and adding the params as a hashtable is the only way to do it
$additionalParams = New-Object -TypeName Hashtable;

$params = Get-Content $ArmParametersPath -Raw | ConvertFrom-Json;

foreach($p in $params | Get-Member -MemberType *Property)
{
	# Check if the parameter is a reference to a Key Vault secret
	if (($params.$($p.Name).reference) -and
		($params.$($p.Name).reference.keyVault) -and
		($params.$($p.Name).reference.keyVault.id) -and
		($params.$($p.Name).reference.secretName))
	{
		$vaultName = Split-Path $params.$($p.Name).reference.keyVault.id -Leaf
        $secretName = $params.$($p.Name).reference.secretName
        if (CheckIfPossiblyUriAndIfNeedToGenerateSas -name $p.Name -generate $GenerateSas) {
            #if parameter name contains msdeploy or url - it is great point of deal that we have URL to our package here
            $secret = TryGenerateSas -maybeStorageUri (Get-AzureKeyVaultSecret -VaultName $vaultName -Name $secretName).SecretValueText
        }
        else {
            $secret = (Get-AzureKeyVaultSecret -VaultName $vaultName -Name $secretName).SecretValue
        }

		$additionalParams.Add($p.Name, $secret);
	}

	# or a normal plain text parameter
	else
	{
        if (CheckIfPossiblyUriAndIfNeedToGenerateSas -name $p.Name -generate $GenerateSas) {
            #process replacement here
            $valueToAdd = TryGenerateSas -maybeStorageUri $params.$($p.Name).value
            $additionalParams.Add($p.Name, $valueToAdd);
        }
        else {
            $additionalParams.Add($p.Name, $params.$($p.Name).value);
        }
	}
}

if ($DeploymentType -eq "infra")
{
    $additionalParams.Set_Item('deploymentId', $RgName);
}
else {
    # read the contents of your Sitecore license file
	$licenseFileContent = Get-Content -Raw -Encoding UTF8 -Path "$($PSScriptRoot)\..\98 License Files\license.xml" | Out-String;
    $additionalParams.Set_Item('licenseXml', $licenseFileContent);
}

#endregion

try {

    Write-Host "Check if resource group already exists..."
    $isPresent = Get-AzureRmResourceGroup -Name $RgName -ev notPresent -ea 0;
    
    if (!$isPresent)
    {
        if ($DeploymentType -ne "infra")
        {
            #if it is not an infra deployment - than we shall throw error
            throw "Resource group is not present, exiting"
        }
        New-AzureRmResourceGroup -Name $RgName -Location $location;
    }

    Write-Verbose "Starting ARM deployment...";

    if ($DeploymentType -eq "infra")
    {
        $deploymentName = "sitecore-$DeploymentType"
        New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $RgName -TemplateFile $ArmTemplatePath -TemplateParameterObject $additionalParams;
    }
    else {
        $deploymentName = "sitecore-msdeploy"
        # Fetch output parameters from Sitecore ARM deployment as authoritative source for the rest of web deploy params
        $sitecoreDeployment = Get-AzureRmResourceGroupDeployment -ResourceGroupName $RgName -Name "sitecore-infra"
        $sitecoreDeploymentOutput = $sitecoreDeployment.Outputs
        $sitecoreDeploymentOutputAsJson =  ConvertTo-Json $sitecoreDeploymentOutput -Depth 5
        $sitecoreDeploymentOutputAsHashTable = ConvertPSObjectToHashtable $(ConvertFrom-Json $sitecoreDeploymentOutputAsJson)

        New-AzureRmResourceGroupDeployment -Name $deploymentName -ResourceGroupName $RgName -TemplateFile $ArmTemplatePath -TemplateParameterObject $additionalParams -provisioningOutput $sitecoreDeploymentOutputAsHashTable;
    }

    Write-Host "Deployment Complete.";
}
catch
{
    Write-Error $_.Exception.Message
    Break
}
