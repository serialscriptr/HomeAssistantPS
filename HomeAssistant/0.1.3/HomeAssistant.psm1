﻿# New
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
	05/08/2022 - Ryan McAvoy - Removed SSL option, Home Assistant REST api does not support. Added autocomplete for service domains
	06/24/2022 - Ryan McAvoy - Changed sensitive script variables to the private variable scope
	12/06/2022 - Ryan McAvoy - Ip parameter defaults to "homeassistant.local" as this should work for most people. Removed redundant 'mandatory = $false'
	#>
	Param (
		[Parameter(Mandatory = $true, HelpMessage = "Local IP address of the home assistant instance to connect to or Homeassistant.local. Example: 192.168.1.2")]
		[ValidateScript({ $_ -match "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$" -or $_ -ieq "homeassistant.local" })]
		[string]$ip = "homeassistant.local",
		[Parameter(HelpMessage = "Port used to connect to home assistant's web gui. Default is 8123")]
		[string]$port = '8123',
		[Parameter(HelpMessage = "Long-Lived Access Token created under user profile in home assistant.")]
		[string]$token
	)
	
	# Obfuscate the token value in memory and remove the plain text value. Inspired by ITGlueAPI powershell module
	if ([bool]$token)
	{
		Set-Variable -Name "ha_api_token" -Value $(ConvertTo-SecureString -String $token -AsPlainText -Force) -Option ReadOnly -Scope Script -Visibility Private
		Remove-Variable -Name "token" -Force
	}
	else
	{
		Write-Warning "Home Assistant long lived token value not provided, please enter it now"
		$secureToken = Read-Host -AsSecureString
		if ([string]::IsNullOrWhiteSpace($secureToken))
		{
			Write-Warning "Input required, unable to continue"
			Throw
		}
		else
		{
			Set-Variable -Name "ha_api_token" -Value $secureToken -Option ReadOnly -Scope Script -Visibility Private
			Remove-Variable -Name "secureToken" -Force
		}
	}
	
	Set-Variable -Name "ha_api_url" -Value "http://$($ip):$($port)/api/" -Visibility Private -Scope Script -Force
	
	try
	{
		Write-Verbose "Attempting to connect to $ha_api_url"
		
		# build the api header
		Set-Variable -Name "ha_api_headers" -Value @{ Authorization = "Bearer $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ha_api_token)))" } -Visibility Private -Scope Script -Force
		
		# Validate access/authentication to the target home assistant's api
		Invoke-RestMethod -uri $ha_api_url -Method GET -Headers $ha_api_headers -SessionVariable ha_session -ErrorAction Stop | Select-Object -ExpandProperty message
		
		# remove the api header from memory
		Set-Variable -Name "ha_api_headers" -Value $null -Scope Script -Force
		
		# determine if we are running noninteractive
		switch ($psversionTable.PSEdition)
		{
			"Core"{
				$cli = (Get-CimInstance win32_process -Filter "ProcessID=$PID" | where { $_.processname -eq "pwsh.exe" }) | select -expand commandline
			}
			"Desktop"{
				$cli = (Get-CimInstance win32_process -Filter "ProcessID=$PID" | where { $_.processname -eq "powershell.exe" }) | select -expand commandline
			}
		}
		
		if ($cli -inotlike "*-NonInteractive*" -or $cli -inotlike "*-NoProfile*")
		{
			# running interactively
			Write-Verbose "Checking some environment information..."
			Set-Variable -Name "ha_all_entities" -Value $(Get-HAEntityID) -Visibility Private -Scope Script -Force
			Set-Variable -Name "ha_all_services" -Value $(Get-HAService) -Visibility Private -Scope Script -Force
			Write-Verbose "Setting up autocomplete helpers..."
			$entity_autocomplete = {
				param ($commandName,
					$parameterName,
					$stringMatch)
				$ha_all_entities.entity_id | Where-Object {
					$_ -like "$stringMatch*"
				} | ForEach-Object {
					"'$_'"
				}
				
			}
			$servicedomain_autocomplete = {
				param ($commandName,
					$parameterName,
					$stringMatch)
				$ha_all_services.domain | Where-Object {
					$_ -like "$stringMatch*"
				} | ForEach-Object {
					"'$_'"
				}
			}
			Register-ArgumentCompleter -CommandName Get-HALogBook, Invoke-HAService, Get-HAState, Get-HAStateHistory, Set-HAState -ParameterName entity_id -ScriptBlock $entity_autocomplete
			Register-ArgumentCompleter -CommandName Invoke-HAService, Get-HAServiceEntity -ParameterName ServiceDomain -ScriptBlock $servicedomain_autocomplete
		}
		else
		{
			Write-Verbose "Running noninteractive, skipping registering autocompleters"
		}	
	}
	catch
	{
		Write-Warning "Connection to Home-Assistant API failed. Double check your token."
		
		$ha_all_entities = $null
		$ha_api_url = $null
		$ha_api_headers = $null
		Throw
	}
	
	Write-Output "Connection to Home-Assistant API succeeded!"
	Return $return.message
}

function New-HATimeStamp
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
	New-HATimeStamp -pstime $(get-date)

	Description
	---------------------------------------
	Returns an ISO 8601 formatted time stamp of the current time and date

	.EXAMPLE
	New-HATimeStamp -year 2022 -month 01 -day 05

	Description
	---------------------------------------
	Returns an ISO 8601 formatted time stamp for the date 01/05/2022 with no time as hour and minutes parameter are not provided.

	.INPUTS
	System.int32, System.DateTime

	.OUTPUTS
	System.String

	.NOTES
	FunctionName : New-HATimeStamp
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

# Get
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
	$($(Invoke-HARestMethod -RestMethod get -Endpoint "services") | Sort-Object -Property domain)
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
	switch ($SortBy)
	{
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
	
	if ($end_time -or $entity_id)
	{
		$Arguments = '?'
	}
	
	foreach ($Param in $($PSBoundParameters.Keys | Where-Object { $_ -ine "start_time" }))
	{
		switch ($Param)
		{
			"entity_id" {
				if ($Arguments -eq '?')
				{
					$Arguments = "$Arguments" + "entity=$entity_id"
					Write-Verbose "args equal $Arguments"
				}
				else
				{
					$Arguments = "$Arguments" + "&entity=$entity_id"
					Write-Verbose "args equal $Arguments"
				}
				
			}
			"end_time" {
				if ($Arguments -eq '?')
				{
					$Arguments = "$Arguments" + "end_time=$end_time"
					Write-Verbose "args equal $Arguments"
				}
				else
				{
					$Arguments = "$Arguments" + "&end_time=$end_time"
					Write-Verbose "args equal $Arguments"
				}
			}
		}
	}
	
	if ($start_time)
	{
		if ($Arguments)
		{
			Write-Verbose "Invoking get REST method on endpoint `"logbook/$start_time`" with args $Arguments"
			Invoke-HARestMethod -RestMethod get -Endpoint "logbook/$start_time" -Arguments $Arguments
		}
		else
		{
			Write-Verbose "Invoking get REST method on endpoint `"logbook/$start_time`""
			Invoke-HARestMethod -RestMethod get -Endpoint "logbook/$start_time"
		}
	}
	else
	{
		if ($Arguments)
		{
			Write-Verbose "Invoking get REST method on endpoint `"logbook`" with args $Arguments"
			Invoke-HARestMethod -RestMethod get -Endpoint "logbook" -Arguments $Arguments
		}
		else
		{
			Write-Verbose "Invoking get REST method on endpoint `"logbook`""
			Invoke-HARestMethod -RestMethod get -Endpoint "logbook"
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
	
	if ($entity_id -or $end_time -or $minimal_response -or $no_attributes -or $significant_changes_only)
	{
		Write-Verbose "One or more parameters provided shall be passed as args"
		$Arguments = "?"
	}
	else
	{
		Write-Verbose "No parameters provided that would be passed as args. This will return a lot of data and take some time, consider using on of the three switch parameters."
	}
	
	forEach ($param in $($PSBoundParameters.Keys | where { $_ -ine "start_time" }))
	{
		switch ($param)
		{
			"end_time" {
				if ($Arguments -eq "?")
				{
					$Arguments = "$Arguments" + "end_time=$end_time"
					Write-Verbose "Args equal $Arguments"
				}
				else
				{
					$Arguments = "$Arguments" + "&end_time=$end_time"
					Write-Verbose "Args equal $Arguments"
				}
				
			}
			"entity_id" {
				if ($entity_id.Count -gt 1)
				{
					Write-Verbose "Multiple entities provides, putting them in corret format now"
					$entities = $entity_id -join ","
					Write-Verbose "entities equals $entities"
				}
				else
				{
					Write-Verbose "Only one entity provided so it shall remain in the format provided"
					$entities = $entity_id
				}
				
				if ($Arguments -eq "?")
				{
					$Arguments = "$Arguments" + "filter_entity_id=$entities"
					Write-Verbose "Args equal $Arguments"
				}
				else
				{
					$Arguments = "$Arguments" + "&filter_entity_id=$entities"
					Write-Verbose "Args equal $Arguments"
				}
				
			}
			"minimal_response" {
				if ($Arguments -eq "?")
				{
					$Arguments = "$Arguments" + "minimal_response"
					Write-Verbose "Args equal $Arguments"
				}
				Else
				{
					$Arguments = "$Arguments" + "&minimal_response"
					Write-Verbose "Args equal $Arguments"
				}
			}
			"no_attributes" {
				if ($Arguments -eq "?")
				{
					$Arguments = "$Arguments" + "no_attributes"
					Write-Verbose "Args equal $Arguments"
				}
				Else
				{
					$Arguments = "$Arguments" + "&no_attributes"
					Write-Verbose "Args equal $Arguments"
					
				}
				
			}
			"significant_changes_only" {
				if ($Arguments -eq "?")
				{
					$Arguments = "$Arguments" + "significant_changes_only"
					Write-Verbose "Args equal $Arguments"
				}
				Else
				{
					$Arguments = "$Arguments" + "&significant_changes_only"
					Write-Verbose "Args equal $Arguments"
				}
			}
		}
	}
	
	if ($start_time)
	{
		if ($Arguments)
		{
			try
			{
				Write-Verbose "Invoking get REST method on endpoint `"history/period/$start_time`" with the following args $Arguments"
				Invoke-HARestMethod -RestMethod get -Endpoint "history/period/$start_time" -Arguments $Arguments | Select-Object -ExpandProperty SyncRoot
			}
			catch
			{
				$Error[0]
			}
		}
		else
		{
			try
			{
				Write-Verbose "Invoking get REST method on endpoint `"history/period/$start_time`""
				Invoke-HARestMethod -RestMethod get -Endpoint "history/period/$start_time" | Select-Object -ExpandProperty SyncRoot
			}
			catch
			{
				$Error[0]
			}
		}
	}
	else
	{
		if ($Arguments)
		{
			try
			{
				Write-Verbose "Invoking get REST method on endpoint `"history`" with the following args $Arguments"
				Invoke-HARestMethod -RestMethod get -Endpoint "history/period" -Arguments $Arguments | Select-Object -ExpandProperty SyncRoot
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
				Write-Verbose "Invoking get REST method on endpoint `"history`""
				Invoke-HARestMethod -RestMethod get -Endpoint "history/period" | Select-Object -ExpandProperty SyncRoot
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
		[string]$entity_id,
		[parameter(Mandatory = $true, HelpMessage = "Image file output path. Full name of file or just the path can be used.")]
		[string]$FileOutput
	)
	
	$LastChar = $FileOutput.Substring($($FileOutput.Length - 1))
	if ($LastChar -eq "\")
	{
		$Output = $FileOutput + "ha_image.jpg"
	}
	else
	{
		$Output = $FileOutput
	}
	
	# Invoke-HARestMethod wont be used here as data will be directly written to the file system
	if ([bool]$ha_api_url)
	{
		# build the api header
		Set-Variable -Name "ha_api_headers" -Value @{ Authorization = "Bearer $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ha_api_token)))" } -Visibility Private -Scope Script -Force
		
		$url = $("$ha_api_url" + "camera_proxy/$entity_id")
		Invoke-WebRequest -UseBasicParsing -Uri $url -Headers $ha_api_headers -OutFile $Output
		
		# remove the api header from memory
		Set-Variable -Name "ha_api_headers" -Value $null -Scope Script -Force
	}
	else
	{
		Write-Warning "Authenticate to home assistant by first using 'New-HASession'"; throw
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

function Get-HAServiceEntity
{
	param
	(
		[parameter(Mandatory = $true)]
		[String]$ServiceDomain
	)
	
	Get-HAEntityID | Where-Object {
		$_.domain -imatch $ServiceDomain
	} | Select-Object -ExpandProperty entity_id
}

function Get-HACalendar
{
	<#
	.SYNOPSIS
	Return list of calendar entities
		
	.DESCRIPTION
	When no parameters are provided a list of calendars are returned. When a calendar entity is provided with the entity_id parameter a list of
	calendar entries are returned that fall within the last 24 hours for the provided calendar. Start and end times can be optionally provided to
	return more calendar entries.
		
	.PARAMETER entity_id
	The calendar entity_id to query calendar entries
	
	.PARAMETER start_time
	The starting date to limit calendar entries returned
	
	.PARAMETER end_time
	The ending date to limit calendar entries returned

	.EXAMPLE
	Get-HACalendar

	.EXAMPLE
	Get-HACalendar -entity_id "Calendar.Calendar"

	.INPUTS
	System.String

	.OUTPUTS
	System.PsObject

	.NOTES
	FunctionName : Get-HACalendar
	Created by   : Ryan McAvoy
	Date Coded   : 12/11/2022
	More info    : https://serialscript.tech
	#>
	
	param (
		[parameter(HelpMessage = "Calendar entity id")]
		[string]$entity_id,
		[parameter(HelpMessage = "The starting date to limit calendar entries returned. Defaults to 24 hours ago")]
		[string]$start_time = $(New-HATimeStamp -pstime $($(Get-date).adddays(-1))),
		[parameter(HelpMessage = "The end date to limit calendar entires returned. Defaults to current date/time")]
		[string]$end_time = $(New-HATimeStamp -pstime $(Get-date))
	)
	
	# validate start/end times to verify a positive time span is returned
	[datetime]$start = ConvertFrom-HATimeStamp -TimeStamp $start_time
	[datetime]$end = ConvertFrom-HATimeStamp -TimeStamp $end_time
	$timespan = New-TimeSpan -Start $start -End $end
	
	if ($timespan.TotalMilliseconds -le -1)
	{
		Write-Warning -Message "Provided start and end time result in a negative time span, time span must return positive value to be valid."
		throw
	}
	
	if ([bool]$entity_id)
	{
		Invoke-HARestMethod -RestMethod get -endpoint "calendars/$entity_id`?start=$start_time&end=$end_time"
	}
	else
	{
		Invoke-HARestMethod -RestMethod get -Endpoint "calendars"
	}
}

function Get-HADeviceID
{
	<#
	.SYNOPSIS
	Return a device id for a provided entity id
		
	.DESCRIPTION
	Using a home assistant template we can pull the device for a given entity id
	
	.PARAMETER entity_id
	Any entity id of a device

	.EXAMPLE
	Get-HADeviceID -entity_id "light.top_shelf_strip"

	.INPUTS
	System.String

	.OUTPUTS
	System.String

	.NOTES
	FunctionName : Get-HADeviceID
	Created by   : Ryan McAvoy
	Date Coded   : 1/20/2024
	More info    : https://serialscript.tech
	#>
	
	param (
		[parameter(Mandatory, HelpMessage = "Entity id of a device")]
		[string]$entity_id
	)
	
	Test-HATemplate -template "{{device_id('$entity_id')}}"
}

function Get-HADeviceEntity
{
	<#
	.SYNOPSIS
	Return all entity ids for a provided device id
		
	.DESCRIPTION
	Using a home assistant template we can pull the entity ids for a provided device id
	
	.PARAMETER device_id
	Any valid device id. Use Get-HADeviceID to get a device id

	.EXAMPLE
	Get-HADeviceEntity -device_id "7146b8be50a2ee9cc09594184c6a01f6"

	.INPUTS
	System.String

	.OUTPUTS
	String Array

	.NOTES
	FunctionName : Get-HADeviceEntity
	Created by   : Ryan McAvoy
	Date Coded   : 1/20/2024
	More info    : https://serialscript.tech
	#>
	
	param (
		[parameter(Mandatory, HelpMessage = "Device id of a device")]
		[string]$device_id
	)
	
	Test-HATemplate -template "{{ device_entities('$device_id') }}"
}

# Invoke
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
	<#
	# this is incorrectly thowing when it shouldnt
	if ($ServiceDomain)
	{
		$ValidServices = Get-HAService
		
		if ($ValidServices.domain -icontains $ServiceDomain)
		{
			Write-Warning "Provided service domain is not valid for this home assistant instance."; throw
		}
		else
		{
			$MatchingDomainServices = $($ValidServices | where-object { $_.domain -ieq $ServiceDomain } | select-object -ExpandProperty services) | Get-Member -MemberType NoteProperty | Select-Object -ExpandProperty Name
			if (!($MatchingDomainServices -icontains $Service))
			{
				Write-Warning "Provided service method is not a valid method for the provided service domain."; throw
			}
		}
	}
	else
	{
		$ServiceDomain = $entity_id -replace "\..*"
	}
	#>
	
	if (!$ServiceDomain)
	{
		$ServiceDomain = $entity_id -replace "\..*"
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
	$Check = Invoke-RestMethod -Method get -uri ($ha_api_url) -Headers $ha_api_headers
	
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
	
	.CHANGES
	12/06/2022 - Ryan McAvoy - Added common parameter set to include verbose support. Added some verbose logging. Removed first option in parameter switch
	#>
	[cmdletbinding()]
	param
	(
		[parameter(Mandatory = $true)]
		[ValidateSet("get", "post")]
		[string]$RestMethod,
		[parameter(Mandatory = $true)]
		[string]$Endpoint,
		[parameter()]
		[string]$Arguments,
		[parameter()]
		[string]$Body
	)
	
	try
	{
		# build the api header
		Set-Variable -Name "ha_api_headers" -Value @{ Authorization = "Bearer $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($ha_api_token)))" } -Visibility Private -Scope Script -Force
		
		$JoinedParams = $($PSBoundParameters.keys | Sort-Object) -join ""
		switch ($JoinedParams)
		{
			<#
			# This should never be reached as endpoint is mandatory
			"ArgumentsRestMethod" {
				Write-Verbose "Invoking $RestMethod method on $ha_api_url with the following arguments: $Arguments"
				Invoke-RestMethod -Method $RestMethod -uri ("$ha_api_url" + $Arguments) -Headers $ha_api_headers -ErrorAction Stop
			}
			#>
			"EndpointRestMethod" {
				Write-Verbose "Invoking $RestMethod method on $ha_api_url with the following endpoint: $Endpoint"
				Invoke-RestMethod -Method $RestMethod -uri ("$ha_api_url" + $Endpoint) -Headers $ha_api_headers -ErrorAction Stop
				
				# remove the api header from memory
				Set-Variable -Name "ha_api_headers" -Value $null -Scope Script -Force
			}
			"BodyEndpointRestMethod" {
				Write-Verbose "Invoking $RestMethod method on $ha_api_url with the following endpoint: $Endpoint and the following body: $Body"
				Invoke-RestMethod -Method $RestMethod -uri ("$ha_api_url" + $Endpoint) -Body $Body -Headers $ha_api_headers -ErrorAction Stop
				
				# remove the api header from memory
				Set-Variable -Name "ha_api_headers" -Value $null -Scope Script -Force
			}
			"ArgumentsEndpointRestMethod" {
				Write-Verbose "Invoking $RestMethod method on $ha_api_url with the following endpoint: $Endpoint and the following arguments: $Arguments"
				Invoke-RestMethod -Method $RestMethod -uri ("$ha_api_url" + $Endpoint + $Arguments) -Headers $ha_api_headers -ErrorAction Stop
				
				# remove the api header from memory
				Set-Variable -Name "ha_api_headers" -Value $null -Scope Script -Force
			}
			default {
				# should never be reached
				throw
			}
		}
	}
	Catch
	{
		Write-Verbose "Error reached, logging error and checking connection to home assistant server"
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
			Write-Warning "Home assistant api check resulted in a failure. Error message follows:"
			$HAError; Throw
		}
	}
}

function Invoke-HAEvent
{
	# THIS STILL NEEDS TESTING
	param
	(
		[parameter(Mandatory = $true)]
		[string]$event_type,
		[parameter()]
		$event_data
	)
	
	if ([bool]$event_data)
	{
		Invoke-HARestMethod -RestMethod post -Endpoint "events/$event_type" -Body $event_data
	}
	else
	{
		Invoke-HARestMethod -RestMethod post -Endpoint "events/$event_type"
	}
}

# Set
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

# Test
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

# ConvertFrom
function ConvertFrom-HATimeStamp
{
	<#
	.SYNOPSIS
	Converts ISO 8601 timestamp to powershell date time object
		
	.DESCRIPTION
	Extremely simple helper function to assist anyone using this module that doesn't know how to convert ISO 8601 timestamps to datetime objects
		
	.PARAMETER TimeStamp
	The ISO 8601 timestamp to convert into a datetime object

	.EXAMPLE
	$TimeStamp = New-HATimeStamp -pstime $(get-date)
	ConvertFrom-HATimeStamp -TimeStamp $TimeStamp

	.INPUTS
	System.String

	.OUTPUTS
	System.DateTime

	.NOTES
	FunctionName : ConvertFrom-HATimeStamp
	Created by   : Ryan McAvoy
	Date Coded   : 12/11/2022
	More info    : https://serialscript.tech
	#>
	
	param (
		[parameter(Mandatory = $true)]
		[string]$TimeStamp
	)
	
	[datetime]::parse($TimeStamp)
}

## HELPER FUNCTIONS ##
# The goal of the functions below is to assist those who don't know how to invoke common services in Home Assistant
# The functions below will provide an example of running common services as well being fully functional

# lights
function Set-HALight
{
	param (
		[parameter(Mandatory = $true, HelpMessage = "the entity id of the light to toggle/turn off/on")]
		[string]$entity_id,
		[parameter()]
		[validateset("toggle","turn_on","turn_off")] # valid services can be pulled from Get-HAService
		[string]$service = "toggle"
	)
	
	Invoke-HAService -ServiceDomain "light" -Service $service -entity_id $entity_id
}