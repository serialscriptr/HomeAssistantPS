# Home Assistant Powershell Wrapper

This is an update of the original project created by Flemming Sørvollen Skaret here: https://github.com/flemmingss/Home-Assistant-PowerShell-Module I updated it mostly because I wanted to improve my powershell skills but also because I enjoy Home Assistant and it seemed like a good place to start. If you have suggestions of ways I can improve my code please open an issue.

I updated the module by adding many of the missing REST endpoints, adding error handling for all functions, and I also made some changes based on powershell best practices.

See Home Assistant REST API docs here: https://developers.home-assistant.io/docs/api/rest/

# To do:
- Provide proper help information for each function
- Determine a better way to store the authentication token and also determine when it needs to be re-authenticated
- Create a function that pulls all entity ids for the given service domain
- Create function for events/<event_type>
- Update some of the functions to default to asking for confirmation before running
- (if possible) dynamically ask for confirmation based on a lack of specific parameters. Ex: Get-HAStateHistory returns a lot of data and takes a long time compared to other functions in the module. If the user were to run the functions without the various parameters that filter the query to Home Assistant then the output returned can be incredibley long depending on how many entities you have and also the provided start time parameter if any.
- Make Invoke-HARestMethod public but not advertised so experienced users can directly call the function with whatever endpoint etc
- Update all functions to better support -verbose parameter
- Update majority of functions to support -whatif parameter
- (Maybe) Provide specific functions for various home assistant service domains
- (If possible) find a way to make Get-HACameraProxy useful within powershell

# Using the module
You can download the module script and execute it to load the modules into memory on the fly by doing the following:
> (new-object Net.WebClient).DownloadString('https://raw.githubusercontent.com/serialscriptr/HomeAssistantPS/master/HomeAssistant/0.1.0/HomeAssistant.psm1') | iex

Note that the above will throw an error because of the inclusion of 'Export-ModuleMember.' This can be ignored, just know that private functions of the module will also be exposed.

You can also install the module to your computer by downloading a copy of the repo and copying the HomeAssistant folder to the "$HOME\Documents\PowerShell\Modules" folder on your computer
