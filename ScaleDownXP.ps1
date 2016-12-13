
$Name = "RESOURCE_GROUP_NAME";
$AzureSubscriptionId = "AZURE_SUBSCRIPTION_ID";


$NewDatabaseEdition = "Standard";
$NewDatabasePricingTier = "S0" # the default database tier of Sitecore XP provisioning script is S1
$NewHostingPlanTier = "Basic"; # the default hosting plan tier of Sitecore XP provisioning script is Standard

#region Service Principle Details

# By default this script will prompt you for your Azure credentials but you can update the script to use an Azure Service Principal instead by following the details at the link below and updating the four variables below once you are done.
# https://azure.microsoft.com/en-us/documen tation/articles/resource-group-authenticate-service-principal/

$UseServicePrinciple = $false;
$TenantId = "SERVICE_PRINCIPAL_TENANT_ID";
$ApplicationId = "SERVICE_PRINCIPAL_APPLICATION_ID";
$ApplicationPassword = "SERVICE_PRINCIPAL_APPLICATION_PASSWORD";

#endregion

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

    
    Write-Host "Group all databases into one server...";

    New-AzureRmSqlDatabaseCopy -ResourceGroupName $Name -ServerName "$Name-web-sql" -DatabaseName "$Name-web-db" -CopyServerName "$Name-sql" -CopyDatabaseName "$Name-web-db"

    Remove-AzureRmSqlServer -ResourceGroupName $Name -ServerName "$Name-web-sql" -Force


    Write-Host "Starting database scaling...";

    $DatabaseNames = "core-db", "master-db", "web-db", "reporting-db";

    Foreach ($DatabaseName in $DatabaseNames)
    {
        Set-AzureRmSqlDatabase -DatabaseName "$Name-$DatabaseName" -ServerName "$Name-sql" -ResourceGroupName $Name -Edition $NewDatabaseEdition -RequestedServiceObjectiveName $NewDatabasePricingTier
    }

    
    Write-Host "Starting hosting plan scaling...";

    $HostingPlans = "cd-hp", "cm-hp", "prc-hp", "rep-hp";

    Foreach($HostingPlan in $HostingPlans)
    {
        Set-AzureRmAppServicePlan -ResourceGroupName $Name -Name "$Name-$HostingPlan" -Tier $NewHostingPlanTier
    }


    Write-Host "Scaling finished.";
}
catch 
{
    Write-Error $_.Exception.Message
    Break 
}