Function New-HASession
{
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
	Invoke-HARestMethod -RestMethod get -Endpoint "config"
}

function Get-HAState
{
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
	$($(Invoke-HARestMethod -RestMethod get -Endpoint "services") | Sort-Object -Property domain )
}

Function Invoke-HAConfigCheck
{
	Invoke-HARestMethod -RestMethod post -Endpoint "config/core/check_config"
}

Function Get-HAEvent
{
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
		[bool]$significant_changes_only = $false
	)
	
	$Arguments = "?"
	
	forEach ($param in $($PSBoundParameters.Keys | where {$_ -ine "start_time"}))
	{
		switch ($param) {
			"end_time" {
				$Arguments = $Arguments + "end_time=$end_time"
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
				
				$Arguments = $Arguments + "&filter_entity_id=$entities"				
			}
			"minimal_response" {
				$Arguments = $Arguments + "&minimal_response"
			}
			"no_attributes" {
				$Arguments = $Arguments + "&no_attributes"
			}
			"significant_changes_only" {
				$Arguments = $Arguments + "&significant_changes_only"
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
			Invoke-HARestMethod -RestMethod get -Endpoint "history/period" -Arguments $Arguments
		}
		else
		{
			Invoke-HARestMethod -RestMethod get -Endpoint "history/period"
		}
	}
}

function Get-HAErrorLog
{
	Invoke-HARestMethod -RestMethod get -Endpoint "error_log"
}

function Get-HACameraProxy
{
	param
	(
		[parameter(Mandatory = $true, HelpMessage = "Entity id of the camera to return image data from")]
		[string]$entity_id
	)
	
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
	$Services = Get-HAService
	
	Return $($Services | select-object -ExpandProperty domain)
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