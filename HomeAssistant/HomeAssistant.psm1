Function New-HASession
{
<#
.SYNOPSIS
Connects to a Home Assistant
	
.DESCRIPTION
Authenticates to the provided Home Assistant so all other functions of the module can run.
	
.PARAMETER ip
IP address of the Home Assistant to connect to or homeassistant.local
	
.PARAMETER port
Optional parameter to specify the port of the Home Assistant to connect to. Defaults to 8123
	
.PARAMETER token
Long lived access token created under user profile in Home Assistant web ui. 
	
.INPUTS
System.String, System.Boolean

.OUTPUTS
System.String

.NOTES
FunctionName : Invoke-HAService
Created by   : Flemming Sørvollen Skaret
Original Release Date : 17.03.2019
Original Project : https://github.com/flemmingss/

.CHANGES:
04/23/2022 - Ryan McAvoy - Changed parameters from being all mandatory. Port defaults to 8123. UseSSL parameter added. Changed Write-host to Write-output
						   added registration of auto completers for entity id parameters in module functions. Added parameter validate scripts. Changed
						   from setting various variables as global and instead made them local to the script for privacy reasons.
#>
	Param (
		[Parameter(Mandatory = $true, HelpMessage = "Local IP address of the home assistant instance to connect to or Homeassistant.local. Example: 192.168.1.2")]
		[ValidateScript({ $_ -match "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$" -or $_ -ieq "homeassistant.local" })]
		[string]$ip,
		[Parameter(Mandatory = $false, HelpMessage = "Port used to connect to home assistant's web gui. Default is 8123")]
		[string]$port = '8123',
		[Parameter(Mandatory = $true, HelpMessage = "Long-Lived Access Token created under user profile in home assistant.")]
		[string]$token,
		[Parameter(Mandatory = $false)]
		[bool]$UseSSL = $false 
	)
	
	$script:ha_api_headers = @{ Authorization = "Bearer " + $token }
	if ($UseSSL)
	{
		$script:ha_api_url = "https://" + "$ip" + ":" + "$port" + "/api/"
	}
	else
	{
		$script:ha_api_url = "http://" + "$ip" + ":" + "$port" + "/api/"
	}
	
	try
	{
		write-output -inputobject "Testing connection... "
		$api_connection = (Invoke-WebRequest -uri $ha_api_url -Method GET -Headers $ha_api_headers)
		$script:ha_api_configured = $true
		Write-Output "Checking some environment information..."
		$script:ha_all_entities = Get-HAEntityID
		Write-Output "Setting up autocomplete helpers..."
		$entity_autocomplete = {
			param ($commandName,$parameterName,$stringMatch)
			$ha_all_entities.entity_id | Where-Object {
				$_ -like "$stringMatch*"
			} | ForEach-Object {
				"'$_'"
			}
			
		}
		Register-ArgumentCompleter -CommandName Get-HALogBook, Invoke-HAService, Get-HAState, Get-HAStateHistory, Set-HAState -ParameterName entity_id -ScriptBlock $entity_autocomplete
		write-output "Connection to Home-Assistant API succeeded! ( $($api_connection.StatusCode) $($api_connection.StatusDescription) )"
		
	}
	catch
	{
		if ((Test-NetConnection -ComputerName $ip -WarningAction SilentlyContinue).PingSucceeded)
		{
			write-output -inputobject "Connection to Home-Assistant API failed!"
		}
		else
		{
			write-output -inputobject "Connection failed - ICMP request timed out!"
		}
		
		$script:ha_all_entities = $null
		$script:ha_api_url = $null
		$script:ha_api_headers = $null
		$script:ha_api_configured = $false
	}
	
}

Function Invoke-HAService
{
<#
.SYNOPSIS
Calls a service within a specific domain.
	
.DESCRIPTION
Triggers the service provided of the service domain for the connected Home Assistant
	
.PARAMETER service
The desired service to call for the connected Home Assistant
	
.PARAMETER serviceDomain
Optional parameter to specify the domain of the service being called
	
.PARAMETER entity_id
Any valid entity id present in the connected Home Assistant
	
.INPUTS
System.String

.OUTPUTS
System.Management.Automation.PSCustomObject

.NOTES
FunctionName : Invoke-HAService
Created by   : Flemming Sørvollen Skaret
Original Release Date : 17.03.2019
Original Project : https://github.com/flemmingss/

.CHANGES:
04/23/2022 - Ryan McAvoy - Changed parameters from being all mandatory. Added service validation check. Change to use Invoke-HARestMethod
#>
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $false)]
		[string]$ServiceDomain,
		[parameter(Mandatory = $true)]
		[string]$Service,
		[parameter(Mandatory = $false)]
		[string]$entity_id
	)
	
	if ($ServiceDomain)
	{
		$ValidServices = Get-HAServiceDomain
		
		if ($ValidServices.domain -icontains $ServiceDomain)
		{
			Write-Warning "Provided service domain is not valid for this home assistant instance."; throw
		}
		else
		{
			$MatchingDomainServices = $ValidServices | where-object { $_.domain -ieq $ServiceDomain } | select-object -ExpandProperty services
			if ($MatchingDomainServices -inotcontains $Service)
			{
				Write-Warning "Provided service method is not a valid method for the provided service domain."; throw
			}
		}
	}
	else
	{
		$ServiceDomain = $Service -replace ".*\."
	}
	
	if ($entity_id)
	{
		$Body = @{
			entity_id = $entity_id
		} | ConvertTo-Json
		Invoke-HARestMethod -RestMethod post -Endpoint "services/$ServiceDomain/$Service" -Body $Body
	}
	else
	{
		Invoke-HARestMethod -RestMethod post -Endpoint "services/$ServiceDomain/$Service"
	}
}

function Get-HAConfig
{
<#
.SYNOPSIS
Returns the current configuration as a psobject
	
.DESCRIPTION
Queries and retuns the current connected Home Assistant configuration. Note this is different from the configuration.yaml file.

.OUTPUTS
System.Management.Automation.PSCustomObject

.NOTES
FunctionName : Get-HAConfig
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	Invoke-HARestMethod -RestMethod get -Endpoint "config"
}

function Get-HAState
{
<#
.SYNOPSIS
Returns a psobject of state objects.
	
.DESCRIPTION
Queries and returns the information on entity states for the connected Home Assistant.

.PARAMETER entity_id
Any valid entity id present in the connected Home Assistant. Used to filter the returned states by the provided entity id.
	
.EXAMPLE
Get-HAState

Description
---------------------------------------
Returns all current entity id states

.INPUTS
System.String

.OUTPUTS
System.Management.Automation.PSCustomObject

.NOTES
FunctionName : Get-HAState
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)]
		[string]$entity_id
	)
	
	if ($entity_id)
	{
		Invoke-HARestMethod -RestMethod get -Endpoint "states/$entity_id"
	}
	else
	{
		Invoke-HARestMethod -RestMethod get -Endpoint "states"
	}
}

Function Get-HAService
{
<#
.SYNOPSIS
Returns a psobject of service objects.
	
.DESCRIPTION
Returns all service domains for the connected Home Assistant and includes valid services that can be called
on the service domain.

.OUTPUTS
System.Management.Automation.PSCustomObject

.NOTES
FunctionName : Get-HAService
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	$($(Invoke-HARestMethod -RestMethod get -Endpoint "services") | Sort-Object -Property domain )
}

Function Invoke-HAConfigCheck
{
<#
.SYNOPSIS
Trigger a check of configuration.yaml

.DESCRIPTION
Triggers a config check for the connected Home Assistant. If successful the psobject returned will have a result
vaule of 'valid'

.INPUTS
System.String

.OUTPUTS
System.Management.Automation.PSCustomObject

.NOTES
FunctionName : Invoke-HAConfigCheck
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	Invoke-HARestMethod -RestMethod post -Endpoint "config/core/check_config"
}

Function Get-HAEvent
{
<#
.SYNOPSIS
Returns an array of event objects
	
.DESCRIPTION
Queries and returns event object names and listener counts for each
	
.PARAMETER sortby
Optional parameter to change how the returned information is sorted, by event or listerner count
	
.INPUTS
System.String

.OUTPUTS
System.Management.Automation.PSCustomObject

.NOTES
FunctionName : Get-HAEvent
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	param
	(
		[parameter(Mandatory = $false)]
		[ValidateSet("event", "listener_count")]
		$SortBy = "event"
	)
	switch ($SortBy) {
		"event" {
			$(Invoke-HARestMethod -RestMethod get -Endpoint "events") | Sort-Object -Property event
		}
		"listener_count" {
			$(Invoke-HARestMethod -RestMethod get -Endpoint "events") | Sort-Object -Property listener_count
		}
		default {
			$(Invoke-HARestMethod -RestMethod get -Endpoint "events") | Sort-Object -Property event
		}
	}
}

Function Get-HALogBook
{
<#
.SYNOPSIS
Returns an array of logbook entries.
	
.DESCRIPTION
Queries and returns the logbook entires based on the given parameters (if any) from the connected Home Assistant
	
.PARAMETER entity_id
Any valid entity id present in the connect Home Assistant to filter the logbook entires to
	
.PARAMETER start_time
An ISO 8601 formatted time stamp that determines the start time of the logbook entires returned.
Defaults to one day before the current day.
	
.PARAMETER end_time
An ISO 8601 formatted time stamp that determines the end time of the logbook entries returned

.EXAMPLE
Get-HALogBook -entity_id $entity

Description
---------------------------------------
Returns logbook entries for the entity_id provided within the last 24 hours as no start time is provided.

.INPUTS
System.String

.OUTPUTS
System.String

.NOTES
FunctionName : Get-HALogbook
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true, HelpMessage = "Filter logbook entries specific to the entity id provided")]
		[String]$entity_id,
		[parameter(Mandatory = $false, HelpMessage = "Optional timestamp in ISO 8601 format (YYYY-MM-DDThh:mm:ssTZD) that determines the start period of the logbook search.")]
		[ValidateScript({ $_ -match "^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?(([+-]\d\d:\d\d)|Z)?$" })]
		[String]$start_time,
		[parameter(Mandatory = $false, HelpMessage = "Optional timestamp ISO 8601 format (YYYY-MM-DDThh:mm:ssTZD) that determines the end period of the logbook search.")]
		[ValidateScript({ $_ -match "^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?(([+-]\d\d:\d\d)|Z)?$" })]
		[String]$end_time
	)
	
	
	$JoinedParams = $($PSBoundParameters.keys | Sort-Object) -join ""
	switch ($JoinedParams)
	{
		"end_timeentity_idstart_time" {
			Invoke-HARestMethod -RestMethod get -Endpoint "logbook/$start_time" -Arguments "?end_time=$end_time&entity=$entity_id"
		}
		"end_timestart_time" {
			Invoke-HARestMethod -RestMethod get -Endpoint "logbook/$start_time" -Arguments "?end_time=$end_time"
		}
		"entity_idstart_time" {
			Invoke-HARestMethod -RestMethod get -Endpoint "logbook/$start_time" -Arguments "?entity=$entity_id"
		}
		"end_timeentity_id" {
			Invoke-HARestMethod -RestMethod get -Endpoint "logbook" -Arguments "?end_time=$end_time&entity=$entity_id"
		}
		"end_time" {
			Invoke-HARestMethod -RestMethod get -Endpoint "logbook" -Arguments "?end_time=$end_time"
		}
		"start_time" {
			Invoke-HARestMethod -RestMethod get -Endpoint "logbook/$start_time"
		}
		"entity_id" {
			Invoke-HARestMethod -RestMethod get -Endpoint "logbook" -Arguments "?entity=$entity_id"
		}
	}
}

function New-TimeStamp
{
<#
.SYNOPSIS
Return a time stamp in ISO 8601 format
	
.DESCRIPTION
Based on the provided input, return an ISO 8601 formated time stamp. Provided input can be a datetime object or
the year, month, day, hour, minute desired. PSTime parameter cannot be used with any other parameter excluding common ones.
	
.PARAMETER years
4 digit integer that represents the year of the time stamp

.PARAMETER month
2 digit integer that represents the month of the time stamp
	
.PARAMETER day
2 digit integer that represents the day of the time stamp
	
.PARAMETER hour
2 digit integer that represents the hour of the time stamp

.PARAMETER minutes
2 digit integer that represents the minutes of the time stamp

.PARAMETER pstime
DateTime object to convert to the ISO 8601 format time stamp. Cannot be used with any other parameter other than common ones.

.EXAMPLE
New-TimeStamp -pstime $(get-date)

Description
---------------------------------------
Returns an ISO 8601 formatted time stamp of the current time and date

.EXAMPLE
New-TimeStamp -year 2022 -month 01 -day 05

Description
---------------------------------------
Returns an ISO 8601 formatted time stamp for the date 01/05/2022 with no time as hour and minutes parameter are not provided.

.INPUTS
System.int32, System.DateTime

.OUTPUTS
System.String

.NOTES
FunctionName : New-TimeStamp
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $false, HelpMessage = "Year for the time stamp output. Must be four digits.")]
		[ValidateScript({ $_ -match "^\d{4}$" })]
		[int]$Year,
		[parameter(Mandatory = $false, HelpMessage = "Month for the time stamp output. Must be two digits and a valid month.")]
		[ValidateRange(01, 12)]
		[int]$Month,
		[parameter(Mandatory = $false, HelpMessage = "Month for the time stamp output. Must be two digits and a valid day.")]
		[ValidateRange(01, 31)]
		[int]$Day,
		[parameter(Mandatory = $false, HelpMessage = "Hour for the time stamp output. Must be two digits and a valid hour.")]
		[ValidateRange(01, 12)]
		[int]$Hour,
		[parameter(Mandatory = $false, HelpMessage = "Minutes for the time stamp output. Example, for the time 1:35 the minutes would be '35'")]
		[ValidateRange(01, 59)]
		[int]$Minute,
		[parameter(Mandatory = $false, HelpMessage = "Any valid datetime input. Cannot be used with any other parameter (common excluded).")]
		[datetime]$pstime
		
	)
	
	if ($pstime -and ($Year -or $Month -or $Day -or $Hour -or $Minute))
	{
		Write-Warning -Message "pstime parameter cannot be used with any other parameter (common excluded)"; Break
	}
	
	if ($pstime)
	{
		Return ($pstime).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffK")
	}
	else
	{
		if ($hour -and $Minute)
		{
			Return ($(Get-Date -Year $Year -Month $Month -Day $Day -Hour $Hour -Minute $Minute)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffK")
		}
		elseif ($hour)
		{
			Return ($(Get-Date -Year $Year -Month $Month -Day $Day -Hour $Hour)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffK")
		}
		elseif ($minute)
		{
			Return ($(Get-Date -Year $Year -Month $Month -Day $Day -Minute $Minute)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffK")
		}
		else
		{
			Return ($(Get-Date -Year $Year -Month $Month -Day $Day)).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ss.fffK")
		}
	}
}

function Get-HAStateHistory
{
<#
.SYNOPSIS
Get CPU info for a list of computers.
.DESCRIPTION
Returns an array of state changes in the past. Each object contains further details for the entities.
The <timestamp> (YYYY-MM-DDThh:mm:ssTZD) is optional and defaults to 1 day before the time of the request. It determines the beginning of the period.
Use the helper function New-TimeStamp to create a timestamp in the proper format.

.PARAMETER start_time
The time stamp in ISO 8601 format which determines the start of the state history period to return

.PARAMETER end_time
The time stamp in ISO 8601 format which determines the end of the state history period to return

.PARAMETER entity_id
Any valid entity id present in the connected Home Assistant. Filters the state history returned to only that of the entity provided.
	
.PARAMETER minimal_response
Optional switch parameter to only return last_changed and state for states other than the first and last state (much faster).

.PARAMETER no_attributes
Optional switch parameter to skip returning attributes from the database (much faster).

.PARAMETER significant_changes_only
Optional switch parameter to only return significant state changes.

.INPUTS
System.String, System.Switch

.OUTPUTS
System.Management.Automation.PSCustomObject

.NOTES
FunctionName : Get-HAStateHistory
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	[CmdletBinding()]
	param
	(
		[parameter(Mandatory = $false, HelpMessage = "Optional timestamp in ISO 8601 format (YYYY-MM-DDThh:mm:ssTZD) that determines the start period of state history returned.")]
		[ValidateScript({ $_ -match "^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?(([+-]\d\d:\d\d)|Z)?$" })]
		[String]$start_time,
		[parameter(Mandatory = $false, HelpMessage = "Optional timestamp ISO 8601 format (YYYY-MM-DDThh:mm:ssTZD) that determines the end period of the state history returned.")]
		[ValidateScript({ $_ -match "^\d{4}-\d\d-\d\dT\d\d:\d\d:\d\d(\.\d+)?(([+-]\d\d:\d\d)|Z)?$" })]
		[String]$end_time,
		[parameter(Mandatory = $false, HelpMessage = "Optiona entity id or array or entity ids to filter the state history queried.")]
		[string[]]$entity_id,
		[parameter(Mandatory = $false, HelpMessage = "Optional parameter to only return last_changed and state for states other than the first and last state (much faster).")]
		[switch]$minimal_response,
		[parameter(Mandatory = $false, HelpMessage = "Optional paramater to skip returning attributes from the database (much faster).")]
		[switch]$no_attributes,
		[parameter(Mandatory = $false, HelpMessage = "Optional paramater to only return significant state changes.")]
		[switch]$significant_changes_only
	)
	
	$Arguments = "?"
	
	forEach ($param in $($PSBoundParameters.Keys | where {$_ -ine "start_time"}))
	{
		switch ($param) {
			"end_time" {
				$Arguments = "$Arguments" + "end_time=$end_time"
			}
			"entity_id" {
				if ($entity_id.Count -gt 1)
				{
					$entities = $entity_id -join ","
				}
				else
				{
					$entities = $entity_id
				}
				
				$Arguments = "$Arguments" + "&filter_entity_id=$entities"				
			}
			"minimal_response" {
				$Arguments = "$Arguments" + "&minimal_response"
			}
			"no_attributes" {
				$Arguments = "$Arguments" + "&no_attributes"
			}
			"significant_changes_only" {
				$Arguments = "$Arguments" + "&significant_changes_only"
			}
		}
	}
	
	if ($start_time)
	{
		if ($Arguments)
		{
			Invoke-HARestMethod -RestMethod get -Endpoint "history/period/$start_time" -Arguments $Arguments
		}
		else
		{
			Invoke-HARestMethod -RestMethod get -Endpoint "history/period/$start_time"
		}
	}
	else
	{
		if ($Arguments)
		{
			try{
				Invoke-HARestMethod -RestMethod get -Endpoint "history/period" -Arguments $Arguments -ErrorAction Stop | select -ExpandProperty SyncRoot
			}
			Catch
			{
				$Error[0]
			}
		
		}
		else
		{
			Try
			{
				Invoke-HARestMethod -RestMethod get -Endpoint "history/period" -ErrorAction Stop | select -ExpandProperty SyncRoot
			}
			Catch
			{
				$Error[0]
			}
		
		}
	}
}

function Get-HAErrorLog
{
<#
.SYNOPSIS
Gets all error logs from the connected Home Assistant

.DESCRIPTION
Retrieve all errors logged during the current session of Home Assistant as a plaintext response.

.INPUTS
System.String

.OUTPUTS
System.String

.NOTES
FunctionName : Get-HAErrorLog
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	Invoke-HARestMethod -RestMethod get -Endpoint "error_log"
}

function Get-HACameraProxy
{
<#
.SYNOPSIS
Returns the data (image) from the specified camera entity_id.

.DESCRIPTION
Function is currently not public because of a lack of understanding of the data that is returned and lack of understanding
how to make the information returned useful.
	
.INPUTS
System.Sting

.OUTPUTS
Bytes I think? I'm not entirely sure

.NOTES
FunctionName : Get-HACameraProxy
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscript.tech
#>
	param
	(
		[parameter(Mandatory = $true, HelpMessage = "Entity id of the camera to return image data from")]
		[string]$entity_id
	)
	
	Invoke-HARestMethod -RestMethod get -Endpoint "camera_proxy/$entity_id"
}

function Invoke-HACheck
{
<#
.SYNOPSIS
Interal helper function error checking
	
FunctionName : Invoke-HACheck
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	if (!$ha_api_configured)
	{
		$false; Break
	}
	
	$Check = Invoke-RestMethod -Method get -uri ("$ha_api_url") -Headers $ha_api_headers
	
	if ($Check -ieq "API running.")
	{
		Return $true
	}
	else
	{
		Return $Check
	}
}

function Invoke-HARestMethod
{
<#
.SYNOPSIS
Interal helper function which all REST queries are called through
	
.NOTES
FunctionName : Invoke-HARestMethod
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("get", "post")]
		[string]$RestMethod,
		[parameter(Mandatory = $true)]
		[string]$Endpoint,
		[parameter(Mandatory = $false)]
		[string]$Arguments,
		[parameter(Mandatory = $false)]
		[string]$Body
	)
	
	if (!$ha_api_configured)
	{
		Write-Warning "No active Home Assistant session found. Run New-HASession before running any other Home Assistant command"; Throw
	}
	
	try
	{
		
		$JoinedParams = $($PSBoundParameters.keys | Sort-Object) -join ""
		switch ($JoinedParams)
		{
			"ArgumentsRestMethod" {
				Invoke-RestMethod -Method $RestMethod -uri ("$ha_api_url" + $Arguments) -Headers $ha_api_headers -ErrorAction Stop
			}
			"EndpointRestMethod" {
				Invoke-RestMethod -Method $RestMethod -uri ("$ha_api_url" + $Endpoint) -Headers $ha_api_headers -ErrorAction Stop
			}
			"BodyEndpointRestMethod" {
				Invoke-RestMethod -Method $RestMethod -uri ("$ha_api_url" + $Endpoint) -Body $Body -Headers $ha_api_headers -ErrorAction Stop
			}
			"ArgumentsEndpointRestMethod" {
				Invoke-RestMethod -Method $RestMethod -uri ("$ha_api_url" + $Endpoint + $Arguments) -Headers $ha_api_headers -ErrorAction Stop
			}
			default {
				# error
				throw
			}
		}
	}
	Catch
	{
		$HAError = $Error[0]
		$Check = Invoke-HACheck
		
		if ($check)
		{
			Write-Warning "Home assistant api check was successful but previous rest command resulted in error."
			switch ($($HAError.ErrorDetails.Message))
			{
				"404: Not Found" {
					Write-Warning "Home assistant returned error 404, are the parameters supplied correct?"; Throw
				}
				"401: Unauthorized" {
					Write-Warning "Home assistant returned error 401, are you authenticated to home assistant?"; Throw
				}
				"400: Bad Request" {
					Write-Warning "Home assistant returned error 400: Bad Request."; Throw
				}
				"405: Method not allowed" {
					Write-Warning "Home assistant returned error 405: Method not allowed."; Throw
				}
				default {
					$HAError; Throw
				}
			}
		}
		else
		{
			Write-Warning "Home assistant api check resulted in a failure."; Throw
		}
	}
	
}

function Get-HAServiceDomain
{
<#
.SYNOPSIS
Get domains for connect Home Assistant services
	
.DESCRIPTION
Gets and returns all valid service domains for the connected Home Assistant

.EXAMPLE
Get-HAServiceDomain

.OUTPUTS
System.Management.Automation.PSCustomObject

.NOTES
FunctionName : 
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	$Services = Get-HAService
	
	Return $($Services | select-object -ExpandProperty domain)
}

function Set-HAState
{
<#
.SYNOPSIS
Sets the state of the given entity id in the connected Home Assistant

.DESCRIPTION
Sets the state of the given entity id to the state given at runtime. Use this function with caution as the state provided is not 
validated by Home Assitant in anyway, meaning the state can be set to anything.

.PARAMETER enitty_id
Any entity id present in the connected Home Assistant
	
.PARAMETER state
The value to set for the state of the entity id given. Can be any value.

.PARAMETER attributes
Optional parameter for setting attributes of the given entity id in PSObject format

.EXAMPLE
$attributes = @{
	next_rising = "2016-05-31T03:39:14+00:00"
	next_setting = "2016-05-31T19:16:42+00:00"
}
Set-HAState -entity_id 'sun.sun' -state "below_horizon" -attributes $attributes

Description
---------------------------------------
Sets the sun entity to the state 'below_horizon' with the attributes 'next_rising' equal to "2016-05-31T03:39:14+00:00" and 
'next_setting' equal to "2016-05-31T19:16:42+00:00"

.INPUTS
System.String, System.Management.Automation.PSCustomObject

.OUTPUTS
System.Management.Automation.PSCustomObject

.NOTES
FunctionName : Set-HAState
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscript.tech
#>
	
	[CmdletBinding(ConfirmImpact = 'High',
				   SupportsShouldProcess = $true)]
	param
	(
		[parameter(Mandatory = $false)]
		[psobject]$attributes,
		[parameter(Mandatory = $true)]
		[string]$state,
		[parameter(Mandatory = $true)]
		[string]$entity_id
	)
	
	if ($PSCmdlet.ShouldProcess($entity_id))
	{
		if ($attributes)
		{
			$Body = @{
				state	   = $state
				attributes = $($attributes | ConvertTo-Json)
			} | ConvertTo-Json
			
			Write-Output -InputObject "Invoking post rest method on host $ha_api_url with endpoint `"states/$entity_id`" with the following body data:"
			Write-Output $Body
		}
		else
		{
			$Body = @{
				state = $state
			} | ConvertTo-Json
			
			Write-Output -InputObject "Invoking post rest method on host $ha_api_url with endpoint `"states/$entity_id`" with the following body data:"
			Write-Output $Body
		}
	}
	
	if ($attributes)
	{
		$Body = @{
			state	   = $state
			attributes = $($attributes | ConvertTo-Json)
		} | ConvertTo-Json
		
		
		Invoke-HARestMethod -RestMethod post -Endpoint "states/$entity_id" -Body $Body
		
	}
	else
	{
		$Body = @{
			state = $state
		} | ConvertTo-Json
		
		
		Invoke-HARestMethod -RestMethod post -Endpoint "states/$entity_id" -Body $Body
	}
}

function Test-HATemplate
{
<#
.SYNOPSIS
Test the validity of a Home Assistant template.
	
.DESCRIPTION
Utilize Home Assistant REST API to test the validity of a Home Assistant template. If the template if valid it returns the value of the given template.
See HA docs on templating for more info: https://www.home-assistant.io/docs/configuration/templating
	
.PARAMETER Template
The template to test against Home Assistant. Ensure any quotes that must be included in the template are prefaced with an escape character.

.EXAMPLE
For the provided Home Assistant template: '{"template": "It is {{ now() }}!"}'
You would need to enter it as follows: "`'{`"template`": `"It is {{ now() }}!`"}`'"

.EXAMPLE
Test-HATemplate -template "`'{`"template`": `"It is {{ now() }}!`"}`'"

Description
---------------------------------------
Test the validity of the provided template. This example at the time of writing returned: {"template": "It is 2022-04-23 14:48:30.718086-04:00!"}

.INPUTS
System.String

.OUTPUTS
System.String

.NOTES
FunctionName : Test-HATemplate
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscript.tech
#>
	param
	(
		[parameter(Mandatory = $true)]
		[string]$template
	)
	
	$Body = @{
		template = $template
	} | ConvertTo-Json
	
	Invoke-HARestMethod -RestMethod post -Endpoint "template" -Body $Body
}

function Get-HAEntityID
{
<#
.SYNOPSIS
Get all entities in the connected Home Assistant session

.DESCRIPTION
Gets list of all entity ids and all entity domains.

.EXAMPLE
Get-HAEntityID

.OUTPUTS
System.Management.Automation.PSCustomObject

.NOTES
FunctionName : Get-HAEntityID
Created by   : Ryan McAvoy
Date Coded   : 04/23/2022
More info    : https://serialscripter.tech
#>
	
	$allEntities = $(Get-HAState) | Select-Object -ExpandProperty entity_id
	$returnEntities = @()
	
	foreach ($entity in $allEntities)
	{
		$psobj = New-Object -TypeName System.Management.Automation.PSObject
		$psobj | Add-Member -NotePropertyName domain -NotePropertyValue $($entity -replace "\..*")
		$psobj | Add-Member -NotePropertyName entity_id -NotePropertyValue $entity
		$returnEntities += $psobj
	}
	
	Return $($returnEntities | Sort-Object -Property domain)
}

$PublicFunctions = "Test-HATemplate", `
"Set-HAState", `
"Get-HAServiceDomain", `
"Invoke-HACheck", `
"Get-HAErrorLog", `
"Get-HAStateHistory", `
"Get-HAStateHistory", `
"New-TimeStamp", `
"Get-HALogBook", `
"Get-HAEvent", `
"Invoke-HAConfigCheck", `
"Get-HAService", `
"New-HASession", `
"Invoke-HAService", `
"Get-HAConfig", `
"Get-HAState", `
"Get-HAEntityID"

Export-ModuleMember -Function $PublicFunctions