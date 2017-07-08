# XP0 Single instance - Re-provisioning application using msdeploy
$ArmTemplatePath = "$($PSScriptRoot)\xp0s-azuredeploy-msdeploy.json";
$ArmParametersPath = "$($PSScriptRoot)\xp0s-azuredeploy-redeploy.parameters.json";

# read the contents of your Sitecore license file
$licenseFileContent = Get-Content -Raw -Encoding UTF8 -Path "$($PSScriptRoot)\license.xml" | Out-String;
$Name = "RESOURCE_GROUP_NAME";
$location = "AZURE_DATA_CENTER_NAME";

Import-Module "$($PSScriptRoot)\..\00 Functions\convert-to-hashtable.psm1"

try {

    Import-Module "$($PSScriptRoot)\..\00 Functions\login-azure-subscription.psm1"
    LoginAzureSubscription
    
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
            $secret = (Get-AzureKeyVaultSecret -VaultName $vaultName -Name $secretName).SecretValue

            $additionalParams.Add($p.Name, $secret);
        }

        # or a normal plain text parameter
        else
        {
            $additionalParams.Add($p.Name, $params.$($p.Name).value);
        }
    }

    $additionalParams.Set_Item('licenseXml', $licenseFileContent);

    #endregion

    Write-Host "Check if resource group already exists..."
    $notPresent = Get-AzureRmResourceGroup -Name $Name -ev notPresent -ea 0;

    if (!$notPresent) 
    {
        New-AzureRmResourceGroup -Name $Name -Location $location;
    }

    # Fetch output parameters from Sitecore ARM deployment as authoritative source for the rest of web deploy params
    $sitecoreDeployment = Get-AzureRmResourceGroupDeployment -ResourceGroupName $Name -Name "sitecore-infra"
    $sitecoreDeploymentOutput = $sitecoreDeployment.Outputs
    $sitecoreDeploymentOutputAsJson =  ConvertTo-Json $sitecoreDeploymentOutput -Depth 5
    $sitecoreDeploymentOutputAsHashTable = ConvertPSObjectToHashtable $(ConvertFrom-Json $sitecoreDeploymentOutputAsJson)
    
    Write-Host "Starting ARM deployment...";
    New-AzureRmResourceGroupDeployment `
        -Name "sitecore-msdeploy" `
        -ResourceGroupName $Name `
        -TemplateFile $ArmTemplatePath `
        -TemplateParameterObject $additionalParams `
        -provisioningOutput $sitecoreDeploymentOutputAsHashTable;
        # -DeploymentDebugLogLevel All -Debug;

    Write-Host "Deployment Complete.";
}
catch 
{
    Write-Error $_.Exception.Message
    Break 
}