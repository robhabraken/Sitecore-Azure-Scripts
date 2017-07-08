# XP0 Single instance - Infrastructure provisioning
$ArmTemplatePath = "$($PSScriptRoot)\xp0s-azuredeploy-infra.json";
$ArmParametersPath = "$($PSScriptRoot)\xp0s-azuredeploy-infra.parameters.json";

$Name = "RESOURCE_GROUP_NAME";
$location = "AZURE_DATA_CENTER_NAME";

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

    $additionalParams.Set_Item('deploymentId', $Name);

    #endregion

    Write-Host "Check if resource group already exists..."
    $notPresent = Get-AzureRmResourceGroup -Name $Name -ev notPresent -ea 0;

    if (!$notPresent) 
    {
        New-AzureRmResourceGroup -Name $Name -Location $location;
    }

    Write-Host "Starting ARM deployment...";
    New-AzureRmResourceGroupDeployment `
        -Name "sitecore-infra" `
        -ResourceGroupName `
        $Name -TemplateFile `
        $ArmTemplatePath `
        -TemplateParameterObject $additionalParams;
        # -DeploymentDebugLogLevel All -Debug;

    Write-Host "Deployment Complete.";
}
catch 
{
    Write-Error $_.Exception.Message
    Break 
}