Function New-HASession
{
	Param (
		[Parameter(Mandatory = $true, HelpMessage = "Local IP address of the home assistant instance to connect to or Homeassistant.local. Example: 192.168.1.2")]
		[ValidateScript({ $_ -match "^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$" -or $_ -ieq "homeassistant.local"})]
		[string]$ip,
		[Parameter(Mandatory = $false, HelpMessage = "Port used to connect to home assistant's web gui. Default is 8123")]
		[int]$port = '8123',
		[Parameter(Mandatory = $true, HelpMessage = "Long-Lived Access Token created under user profile in home assistant.")]
		[string]$token
	)
	
	$script:ha_api_headers = @{ Authorization = "Bearer " + $token }
	$script:ha_api_url = "http://" + "$ip" + ":" + "$port" + "/api/"
	
	try
	{
		write-output -inputobject "Testing connection... "
		$api_connection = (Invoke-WebRequest -uri $ha_api_url -Method GET -Headers $ha_api_headers)
		$script:ha_api_configured = $true
		write-output -inputobject "Connection to Home-Assistant API succeeded! (" ($api_connection).StatusCode ($api_connection).StatusDescription ")"
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
		
		$script:ha_api_url = $null
		$script:ha_api_headers = $null
		$script:ha_api_configured = $false
	}
	
}

Function Invoke-HAService
{
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
	
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}
	
	if ($ServiceDomain)
	{
		$ValidServices = Get-HAServiceDomains
		
		if ($ValidServices.domain -icontains $ServiceDomain)
		{
			Write-Warning "Provided service domain is not valid for this home assistant instance."; throw
		}
		else
		{
			$MatchingDomainServices = $ValidServices | where-object { $_.domain -ieq $ServiceDomain } | select-object -expand services
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
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}
	
	Invoke-HARestMethod -RestMethod get -Endpoint "config"
}

function Get-HAState
{
	[CmdletBinding()]
	Param (
		[Parameter(Mandatory = $false, ValueFromPipelineByPropertyName = $true)
		]
		[string]$entity_id
	)
	
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}	
	
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
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}
	
	Invoke-HARestMethod -RestMethod get -Endpoint "services"
}

Function Invoke-HAConfigCheck
{
	
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}
	
	Invoke-HARestMethod -RestMethod post -Endpoint "config/core/check_config"
}

Function Get-HAEvent
{
	
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}
	
	Invoke-HARestMethod -RestMethod get -Endpoint "events"
}

Function Get-HALogBook
{
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
		
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}
	
	$JoinedParams = $($PSBoundParameters.keys | Sort-Object) -join ""
	switch ($JoinedParams) {
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
	
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}
	
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
		[bool]$minimal_response = $false,
		[parameter(Mandatory = $false, HelpMessage = "Optional paramater to skip returning attributes from the database (much faster).")]
		[bool]$no_attributes = $false,
		[parameter(Mandatory = $false, HelpMessage = "Optional paramater to only return significant state changes.")]
		[bool]$significant_changes_only
	)
	
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}
	
	try
	{
		
		# there has to be a better way to do this...
		if ($entity_id)
		{
			if ($entity_id.Count -gt 1)
			{
				$entities = $entity_id -join ","
			}
			else
			{
				$entities = $entity_id
			}
			
			if ($start_time -and $end_time)
			{
				if ($minimal_response -and $no_attributes -and $significant_changes_only)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&end_time=$end_time&minimal_response&no_attributes&significant_changes_only") -Headers $ha_api_headers
				}
				elseif ($minimal_response -and $no_attributes)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&end_time=$end_time&minimal_response&no_attributes") -Headers $ha_api_headers
				}
				elseif ($minimal_response -and $significant_changes_only)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&end_time=$end_time&minimal_response&significant_changes_only") -Headers $ha_api_headers
				}
				elseif ($no_attributes -and $significant_changes_only)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&end_time=$end_time&no_attributes&significant_changes_only") -Headers $ha_api_headers
				}
				elseif ($no_attributes)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&end_time=$end_time&no_attributes") -Headers $ha_api_headers
				}
				elseif ($minimal_response)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&end_time=$end_time&minimal_response") -Headers $ha_api_headers
				}
				elseif ($significant_changes_only)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&end_time=$end_time&significant_changes_only") -Headers $ha_api_headers
				}
				else
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&end_time=$end_time") -Headers $ha_api_headers
				}
			}
			elseif ($start_time)
			{
				if ($minimal_response -and $no_attributes -and $significant_changes_only)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&minimal_response&no_attributes&significant_changes_only") -Headers $ha_api_headers
				}
				elseif ($minimal_response -and $no_attributes)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&minimal_response&no_attributes") -Headers $ha_api_headers
				}
				elseif ($minimal_response -and $significant_changes_only)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&minimal_respons&significant_changes_only") -Headers $ha_api_headers
				}
				elseif ($no_attributes -and $significant_changes_only)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&no_attributes&significant_changes_only") -Headers $ha_api_headers
				}
				elseif ($no_attributes)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&no_attributes") -Headers $ha_api_headers
				}
				elseif ($minimal_response)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&minimal_response") -Headers $ha_api_headers
				}
				elseif ($significant_changes_only)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities&significant_changes_only") -Headers $ha_api_headers
				}
				else
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities") -Headers $ha_api_headers
				}
			}
			elseif ($end_time)
			{
				if ($minimal_response -and $no_attributes -and $significant_changes_only)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?filter_entity_id=$entities&end_time=$end_time&minimal_response&no_attributes&significant_changes_only") -Headers $ha_api_headers
				}
				elseif ($minimal_response -and $no_attributes)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?filter_entity_id=$entities&end_time=$end_time&minimal_response&no_attributes") -Headers $ha_api_headers
				}
				elseif ($minimal_response -and $significant_changes_only)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?filter_entity_id=$entities&end_time=$end_time&minimal_response&significant_changes_only") -Headers $ha_api_headers
				}
				elseif ($no_attributes -and $significant_changes_only)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?filter_entity_id=$entities&end_time=$end_time&no_attributes&significant_changes_only") -Headers $ha_api_headers
				}
				elseif ($no_attributes)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?filter_entity_id=$entities&end_time=$end_time&no_attributes") -Headers $ha_api_headers
				}
				elseif ($minimal_response)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?filter_entity_id=$entities&end_time=$end_time&minimal_response") -Headers $ha_api_headers
				}
				elseif ($significant_changes_only)
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?filter_entity_id=$entities&end_time=$end_times&significant_changes_only") -Headers $ha_api_headers
				}
				else
				{
					Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?filter_entity_id=$entities&end_time=$end_time") -Headers $ha_api_headers
				}
			}
		}
		elseif ($start_time -and $end_time)
		{
			if ($minimal_response -and $no_attributes -and $significant_changes_only)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?end_time=$end_time&minimal_response&no_attributes&significant_changes_only") -Headers $ha_api_headers
			}
			elseif ($minimal_response -and $no_attributes)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?end_time=$end_time&minimal_response&no_attributes") -Headers $ha_api_headers
			}
			elseif ($minimal_response -and $significant_changes_only)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?end_time=$end_time&minimal_response&significant_changes_only") -Headers $ha_api_headers
			}
			elseif ($no_attributes -and $significant_changes_only)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?end_time=$end_time&no_attributes&significant_changes_only") -Headers $ha_api_headers
			}
			elseif ($no_attributes)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?end_time=$end_time&no_attributes") -Headers $ha_api_headers
			}
			elseif ($minimal_response)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?end_time=$end_time&minimal_response") -Headers $ha_api_headers
			}
			elseif ($significant_changes_only)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?end_time=$end_time&significant_changes_only") -Headers $ha_api_headers
			}
			else
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?end_time=$end_time") -Headers $ha_api_headers
			}
		}
		elseif ($start_time)
		{
			if ($minimal_response -and $no_attributes -and $significant_changes_only)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?minimal_response&no_attributes&significant_changes_only") -Headers $ha_api_headers
			}
			elseif ($minimal_response -and $no_attributes)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?minimal_response&no_attributes") -Headers $ha_api_headers
			}
			elseif ($minimal_response -and $significant_changes_only)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?minimal_respons&significant_changes_only") -Headers $ha_api_headers
			}
			elseif ($no_attributes -and $significant_changes_only)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?no_attributes&significant_changes_only") -Headers $ha_api_headers
			}
			elseif ($no_attributes)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?no_attributes") -Headers $ha_api_headers
			}
			elseif ($minimal_response)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?minimal_response") -Headers $ha_api_headers
			}
			elseif ($significant_changes_only)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?significant_changes_only") -Headers $ha_api_headers
			}
			else
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period/" + $start_time + "?filter_entity_id=$entities") -Headers $ha_api_headers
			}
		}
		elseif ($end_time)
		{
			if ($minimal_response -and $no_attributes -and $significant_changes_only)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?end_time=$end_time&minimal_response&no_attributes&significant_changes_only") -Headers $ha_api_headers
			}
			elseif ($minimal_response -and $no_attributes)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?end_time=$end_time&minimal_response&no_attributes") -Headers $ha_api_headers
			}
			elseif ($minimal_response -and $significant_changes_only)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?end_time=$end_time&minimal_response&significant_changes_only") -Headers $ha_api_headers
			}
			elseif ($no_attributes -and $significant_changes_only)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?end_time=$end_time&no_attributes&significant_changes_only") -Headers $ha_api_headers
			}
			elseif ($no_attributes)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?end_time=$end_time&no_attributes") -Headers $ha_api_headers
			}
			elseif ($minimal_response)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?end_time=$end_time&minimal_response") -Headers $ha_api_headers
			}
			elseif ($significant_changes_only)
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?end_time=$end_times&significant_changes_only") -Headers $ha_api_headers
			}
			else
			{
				Invoke-RestMethod -Method get -uri ("$ha_api_url" + "history/period" + "?end_time=$end_time") -Headers $ha_api_headers
			}
		}
	}
	catch
	{
		$HAError = $Error[0]
	
		# something went wrong, check if the api is still working/connected
		$Check = Invoke-HACheck
	
		if ($Check)
		{
			Write-Warning "Home assistant API is functioning and properly connected but an error occured during this cmdlet. Error:"
			Return $HAError
		}
	}
}

function Get-HAErrorLog
{
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}
	
	Invoke-HARestMethod -RestMethod get -Endpoint "error_log"	
}

function Get-HACameraProxy
{
	param
	(
		[parameter(Mandatory = $true, HelpMessage = "Entity id of the camera to return image data from")]
		[string]$entity_id
	)
	
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}
	
	Invoke-HARestMethod -RestMethod get -Endpoint "camera_proxy/$entity_id"
}

function Invoke-HACheck
{
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
}

function Get-HAServiceDomain
{
	$Services = Get-HAServices
	
	Return $($Services | select-object -expand domain)
}

function Set-HAState
{
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
			Return $Body	
		}
		else
		{
			$Body = @{
				state = $state
			} | ConvertTo-Json
			
			Write-Output -InputObject "Invoking post rest method on host $ha_api_url with endpoint `"states/$entity_id`" with the following body data:"
			Return $Body
		}
		Write-Output -InputObject ""		
	}	
	
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}
	
	if ($attributes)
	{
		$Body = @{
			state = $state
			attributes = $($attributes | ConvertTo-Json)
		} | ConvertTo-Json
		

		Invoke-HARestMethod -RestMethod post -Endpoint "states/$entity_id" -Body $Body
		
	}
	else
	{
		$Body = @{
			state	   = $state
		} | ConvertTo-Json
		
		
		Invoke-HARestMethod -RestMethod post -Endpoint "states/$entity_id" -Body $Body
	}
}

function Check-HATemplate
{
	param
	(
		[parameter(Mandatory = $true)]
		[string]$template
	)
	
	if (!$ha_api_configured)
	{
		write-output -inputobject "No active Home Assistant session. Run 'New-HASession' prior to running this command."; Break
	}
	
	$Body = @{
		template = $template
	} | ConvertTo-Json
	
	Invoke-HARestMethod -RestMethod post -Endpoint "template" -Body $Body
}