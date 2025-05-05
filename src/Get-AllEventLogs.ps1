[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [System.String] $Computer = [Environment]::MachineName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [System.String] $FilterXPath = "*",

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [System.String] $SqlServer = '(localdb)\MSSQLLocalDB',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [System.String] $SqlDatabase = 'EventLogs',

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [System.String] $SqlTable = 'EventData'
)

# Get all event logs and process them
try {
    Write-Host "Fetching event logs from computer: $Computer" -ForegroundColor Green

    $eventLogs = Get-WinEvent -ComputerName $Computer -ListLog * -ErrorAction Stop | Sort-Object LogName

    foreach ($log in $eventLogs) {
        Write-Host "Processing log: $($log.LogName)" -ForegroundColor Yellow

        # Call the external script or function
        . .\Get-LogEventLogs.ps1 `
            -Computer $Computer `
            -LogName $log.LogName `
            -FilterXPath $FilterXPath `
            -SqlServer $SqlServer `
            -SqlDatabase $SqlDatabase `
            -SqlTable $SqlTable
    }

    Write-Host "All logs processed successfully." -ForegroundColor Green
}
catch {
    Write-Error "An error occurred: $_"
}