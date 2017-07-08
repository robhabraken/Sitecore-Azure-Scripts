function LoginAzureSubscription()
{
    $AzureSubscriptionId = "AZURE_SUBSCRIPTION_ID";

    # By default this script will prompt you for your Azure credentials but you can update the script to use an Azure Service Principal instead by following the details at the link below and updating the four variables below once you are done.
    # https://azure.microsoft.com/en-us/documen tation/articles/resource-group-authenticate-service-principal/

    $UseServicePrinciple = $true;
    $TenantId = "SERVICE_PRINCIPAL_TENANT_ID";
    $ApplicationId = "SERVICE_PRINCIPAL_APPLICATION_ID";
    $ApplicationPassword = "SERVICE_PRINCIPAL_APPLICATION_PASSWORD";

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
            Set-AzureRmContext -SubscriptionID $AzureSubscriptionId
        }
        catch
        {
            Login-AzureRmAccount
            Set-AzureRmContext -SubscriptionID $AzureSubscriptionId
        }
        #endregion
    }
}