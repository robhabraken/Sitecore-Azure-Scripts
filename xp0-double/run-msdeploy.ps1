# XP0 Double (CM/CD) - Initial application msdeploy
$ArmTemplatePath = "$($PSScriptRoot)\xp0d-azuredeploy-msdeploy.json";
$ArmParametersPath = "$($PSScriptRoot)\xp0d-azuredeploy-msdeploy.parameters.json";

# read the contents of your Sitecore license file
$licenseFileContent = Get-Content -Raw -Encoding UTF8 -Path "$($PSScriptRoot)\license.xml" | Out-String;
$Name = "YOUR_RESOURCE_GROUP_NAME";
$location = "West Europe";
$AzureSubscriptionId = "YOUR_SUBSCRIPTION_ID";

#region Create Params Object
# license file needs to be secure string and adding the params as a hashtable is the only way to do it
$additionalParams = New-Object -TypeName Hashtable;

$params = Get-Content $ArmParametersPath -Raw | ConvertFrom-Json;

foreach($p in $params | Get-Member -MemberType *Property)
{
    $additionalParams.Add($p.Name, $params.$($p.Name).value);
}

$additionalParams.Set_Item('licenseXml', $licenseFileContent);

#endregion

#region Service Principle Details

# By default this script will prompt you for your Azure credentials but you can update the script to use an Azure Service Principal instead by following the details at the link below and updating the four variables below once you are done.
# https://azure.microsoft.com/en-us/documen tation/articles/resource-group-authenticate-service-principal/

$UseServicePrinciple = $false;
$TenantId = "SERVICE_PRINCIPAL_TENANT_ID";
$ApplicationId = "SERVICE_PRINCIPAL_APPLICATION_ID";
$ApplicationPassword = "SERVICE_PRINCIPAL_APPLICATION_PASSWORD";

#endregion

function ConvertPSObjectToHashtable
{
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process
    {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject) { ConvertPSObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject])
        {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = ConvertPSObjectToHashtable $property.Value
            }

            $hash
        }
        else
        {
            $InputObject
        }
    }
}

try {
    Write-Host "Setting Azure RM Context..."

    if($UseServicePrinciple -eq $true)
    {
        #region Use Service Principle
        $secpasswd = ConvertTo-SecureString $ApplicationPassword -AsPlainText -Force
        $mycreds = New-Object System.Management.Automation.PSCredential ($ApplicationId, $secpasswd)
        Login-AzureRmAccount -ServicePrincipal -Tenant $TenantId -Credential $mycreds

        Set-AzureRmContext -SubscriptionID $AzureSubscriptionId -TenantId $TenantId;
        #endregion
    }
    else
    {
        #region Use Manual Login
        try 
        {
            Write-Host "inside try"
            Set-AzureRmContext -SubscriptionID $AzureSubscriptionId
        }
        catch 
        {
            Write-Host "inside catch"
            Login-AzureRmAccount
            Set-AzureRmContext -SubscriptionID $AzureSubscriptionId
        }
        #endregion      
    }

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

    Write-Verbose "Starting ARM deployment...";
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