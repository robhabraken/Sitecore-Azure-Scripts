## Commands to deploy environment locally

### Authorize manually (VSTS is authorized already) 

Content of following block can be saved at ```/Azure/00 Functions/authorize.ps1``` to ease authorization process locally (```/Azure/00 Functions/authorize.ps1``` shall be ignored in .gitignore)
```
$TenantId = "_TenantId_";
$ApplicationId = "_applicationId_";
$ApplicationPassword = "_applicationPwd_";
$AzureSubscriptionId = "_AzureSubscriptionId_"
$secpasswd = ConvertTo-SecureString $ApplicationPassword -AsPlainText -Force
$mycreds = New-Object System.Management.Automation.PSCredential ($ApplicationId, $secpasswd)
Login-AzureRmAccount -ServicePrincipal -Tenant $TenantId -Credential $mycreds
Set-AzureRmContext -SubscriptionID $AzureSubscriptionId -TenantId $TenantId
	
```
Environment is defined by resource group, template and it's parameters.

### Infra

.\deploy.ps1 -ArmTemplatePath "_pathToArmTemplate_" -ArmParametersPath "_pathToArmTemplateParameters_" -RgName _resourceGroupName_ -DeploymentType infra 

### MsDeploy

.\deploy.ps1 -ArmTemplatePath "_pathToArmTemplate_" -ArmParametersPath "_pathToArmTemplateParameters_" -RgName _resourceGroupName_ -DeploymentType msdeploy 

### Redeploy

.\deploy.ps1 -ArmTemplatePath "_pathToArmTemplate_" -ArmParametersPath "_pathToArmTemplateParameters_" -RgName _resourceGroupName_ -DeploymentType redeploy 
