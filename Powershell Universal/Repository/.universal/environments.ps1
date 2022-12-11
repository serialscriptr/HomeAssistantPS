New-PSUEnvironment -Name "Integrated" -Version "7.2.7" -Path "Universal.Server" -Variables @('*') 
New-PSUEnvironment -Name "Agent" -Version "7.2.7" -Path "Universal.Agent" -Variables @('*') 
New-PSUEnvironment -Name "Powershell Core 7" -Path "/opt/microsoft/powershell/7/pwsh" -Variables @('*')