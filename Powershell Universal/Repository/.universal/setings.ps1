$Parameters = @{
	LoggingFilePath = "/root/.PowerShellUniversal/log.txt"
	LogLevel = "Error"
	MicrosoftLogLevel = "Warning"
	HideRunAs = $true
}
Set-PSUSetting @Parameters