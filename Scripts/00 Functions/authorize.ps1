$TenantId = "YOUR_TENANT_ID"
$ApplicationId = "YOUR_APPLICATION_ID"
$ApplicationPassword = "YOUR_APPLICATION_PASSWORD"
$AzureSubscriptionId = "YOU_SUBSCRIPTION_ID"
$secpasswd = ConvertTo-SecureString $ApplicationPassword -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($ApplicationId, $secpasswd)
Login-AzureRmAccount -ServicePrincipal -Tenant $TenantId -Credential $mycreds
Set-AzureRmContext -SubscriptionID $AzureSubscriptionId -TenantId $TenantId