# Home Assistant Powershell Wrapper

This is an update of the original project created by Flemming Sørvollen Skaret here: https://github.com/flemmingss/Home-Assistant-PowerShell-Module I updated it mostly because I wanted to improve my powershell skills but also because I enjoy Home Assistant and it seemed like a good place to start. If you have suggestions of ways I can improve my code please open an issue.

I updated the module by adding many of the missing REST endpoints and adding error handling etc.

See Home Assistant REST API docs here: https://developers.home-assistant.io/docs/api/rest/

# To do:
- Provide proper help information for each function
- Create function for events/<event_type>
- Update some of the functions to default to asking for confirmation before running
- Update all functions to better support -verbose parameter
- Update majority of functions to support -whatif parameter
- (Maybe) Provide specific functions for various home assistant service domains