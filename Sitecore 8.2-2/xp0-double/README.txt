This deploys a XP deployment with a CM and CD (but no reporting or processing instance like XP-full uses)

For this template to work, you need an XP0 CM web deploy package, and an XP1 CD web deploy package for the two web apps. In other words you need aspects of both the XP0 and XP1 packages Sitecore provides.

NOTE: This script expects a customized version of the XP0 CM web deploy package with these additional Web Deploy parameters added:
IP Security Client IP
IP Security Client IP Mask

Using a stock XP0 package will result in errors; you can also remove those parameters from line ~194 in the msdeploy.json template if you want to be compatible with stock XP0.

(or you can make your own templates with the Azure Toolkit)