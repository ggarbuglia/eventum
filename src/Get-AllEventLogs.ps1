[CmdletBinding()]
param (
    [Parameter()]
    [System.String] $Computer = [Environment]::MachineName,

    [Parameter()]
    [System.String] $FilterXPath = "*",

    [Parameter()]
    [System.String] $SqlServer = '(localdb)\MSSQLLocalDB',

    [Parameter()]
    [System.String] $SqlDatabase = 'EventLogs',

    [Parameter()]
    [System.String] $SqlTable = 'EventData'

)

Clear-Host;

Get-WinEvent -ComputerName $Computer -ListLog * -ErrorAction SilentlyContinue | 
Sort-Object LogName |  
ForEach-Object {
    .\Get-LogEventLogs.ps1 `
        -Computer $Computer `
        -LogName "$($_.LogName)" `
        -FilterXPath $FilterXPath `
        -SqlServer $SqlServer `
        -SqlDatabase $SqlDatabase `
        -SqlTable $SqlTable
}