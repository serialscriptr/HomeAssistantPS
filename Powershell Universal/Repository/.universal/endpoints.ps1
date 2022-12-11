New-PSUEndpoint -Url "/HA/Event" -Description "Returns event types and listener counts" -Method @('GET') -Endpoint {
    Invoke-RestMethod -Method Get -uri $("$HA_URL" + "events") -Headers @{Authorization = "Bearer $($Secret:HA_Secret)"}
    } -Environment "Powershell Core 7" -Tag @('Home Assitant') 
    New-PSUEndpoint -Url "/HA/State" -Description "Returns an array of entity_ids, their state and attributes" -Method @('GET') -Endpoint {
    Param (
            [Parameter(Mandatory = $false)]
            [string]$entity_id
    )
    
    if([bool]$entity_id){
        Invoke-RestMethod -Method Get -uri $("$HA_URL" + "states/$entity_id") -Headers @{Authorization = "Bearer $($Secret:HA_Secret)"}
    }
    else{
        Invoke-RestMethod -Method Get -uri $("$HA_URL" + "states") -Headers @{Authorization = "Bearer $($Secret:HA_Secret)"}
    }
    } -Environment "Powershell Core 7" -Tag @('Home Assitant') 
    New-PSUEndpoint -Url "/HA/Service" -Description "Returns list of service domains and their services" -Method @('GET') -Endpoint {
    Invoke-RestMethod -Method Get -uri $("$HA_URL" + "services") -Headers @{Authorization = "Bearer $($Secret:HA_Secret)"}
    } -Environment "Powershell Core 7" -Tag @('Home Assitant') 
    New-PSUEndpoint -Url "/HA/ErrorLog" -Description "Returns logged errors in the error log" -Method @('GET') -Endpoint {
    Invoke-RestMethod -Method Get -uri $("$HA_URL" + "error_log") -Headers @{Authorization = "Bearer $($Secret:HA_Secret)"}
    } -Environment "Powershell Core 7" -Tag @('Home Assitant') 
    New-PSUEndpoint -Url "/HA/Config" -Method @('GET') -Endpoint {
    Invoke-RestMethod -Method Get -uri $("$HA_URL" + "config") -Headers @{Authorization = "Bearer $($Secret:HA_Secret)"}
    } -Environment "Powershell Core 7" -Tag @('Home Assitant') 
    New-PSUEndpoint -Url "/HA/Services" -Method @('GET') -Endpoint {
    Invoke-RestMethod -Method Get -uri $("$HA_URL" + "services") -Headers @{Authorization = "Bearer $($Secret:HA_Secret)"}
    } -Environment "Powershell Core 7" -Tag @('Home Assitant') 
    New-PSUEndpoint -Url "/HA/Calendars" -Method @('GET') -Endpoint {
    Param (
            [Parameter()]
            [string]$entity_id,
            [Parameter()]
            [string]$start,
            [parameter()]
            [string]$end
    )
    
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
    $entity_id = "calendar.calendar"
    if(!([bool]$start)){
        $start = New-HATimeStamp -pstime $($(Get-date).adddays(-1))
    }
    if(!([bool]$end)){
        $end = New-HATimeStamp -pstime $(get-date)
    }
    
    if([bool]$entity_id){
        Invoke-RestMethod -Method Get -uri $("$HA_URL" + "calendars/$entity_id`?start=$start&end=$end") -Headers @{Authorization = "Bearer $($Secret:HA_Secret)"}
    }
    else{
        Invoke-RestMethod -Method Get -uri $("$HA_URL" + "calendars") -Headers @{Authorization = "Bearer $($Secret:HA_Secret)"}
    }
    } -Environment "Powershell Core 7" -Tag @('Home Assitant') 
    New-PSUEndpoint -Url "/HA/EntityId" -Method @('GET') -Endpoint {
    $ServiceData = $(Invoke-RestMethod http://10.0.0.161:5000/HA/State -Method GET)
    $allEntities = $ServiceData.entity_id
    $returnEntities = @()
        
    foreach ($entity in $allEntities)
    {
        $psobj = New-Object -TypeName System.Management.Automation.PSObject
        $psobj | Add-Member -NotePropertyName domain -NotePropertyValue $($entity -replace "\..*")
        $psobj | Add-Member -NotePropertyName entity_id -NotePropertyValue $entity
        $returnEntities += $psobj
    }
    Return $($returnEntities | Sort-Object -Property domain)
    } -Environment "Powershell Core 7" -Tag @('Home Assitant')