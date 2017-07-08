# XP0 Double (CM/CD) setup #

This deploys an XPx deployment with a CM and CD role, but without a reporting or a processing instance the like the XP full version uses. This can be useful if you do want to test splitting the CD and CM roles, but if you want to save on budget in a test environment by omitting the PRC and REP roles, because they only would be required for handling a lot of traffic. I tend to advise this setup for an acceptance environment (since non-production instances are paid individually).

For this template to work, you need an XP0 Single web deploy package for the CM role, and an XP1 CD web deploy package for the web apps. So it's a combination of of both the XP0 and XP1 packages Sitecore provides.