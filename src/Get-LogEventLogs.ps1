using namespace System.Data.SqlClient

[CmdletBinding()]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [System.String] $Computer = [Environment]::MachineName,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [System.String] $LogName = "Application",

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

# Calculate date range
$sdate = (Get-Date).AddHours(-1).Date
$edate = $sdate.AddHours(1)

$FilterXPath = "*[System[TimeCreated[@SystemTime>='$($sdate.ToUniversalTime().ToString("o"))' and @SystemTime<='$($edate.ToUniversalTime().ToString("o"))']]]"

# Create DataTable
$dataTable = New-Object System.Data.DataTable

$dataTable.Columns.Add('Record', [long]) | Out-Null
$dataTable.Columns.Add('MachineName', [String]) | Out-Null
$dataTable.Columns.Add('Log', [String]) | Out-Null
$dataTable.Columns.Add('Provider', [String]) | Out-Null
$dataTable.Columns.Add('TimeCreated', [DateTime]) | Out-Null
$dataTable.Columns.Add('Event', [Int32]) | Out-Null
$dataTable.Columns.Add('Level', [String]) | Out-Null
$dataTable.Columns.Add('User', [String]) | Out-Null
$dataTable.Columns.Add('Task', [String]) | Out-Null
$dataTable.Columns.Add('Message', [String]) | Out-Null

# Cache for user translations
$userCache = @{}

# Fetch and process events
try {
    Get-WinEvent -ComputerName $Computer -LogName $LogName -FilterXPath $FilterXPath -ErrorAction SilentlyContinue |
    ForEach-Object {
        $user = $null
        if ($_.UserId -and -not $userCache.ContainsKey($_.UserId.Value)) {
            $userCache[$_.UserId.Value] = $_.UserId.Translate([System.Security.Principal.NTAccount]).Value
        }
        $user = $userCache[$_.UserId.Value]

        $dataRow = $dataTable.NewRow()
        $dataRow['Record'] = [Convert]::ToInt64($_.RecordId)
        $dataRow['MachineName'] = $_.MachineName
        $dataRow['Log'] = $_.LogName
        $dataRow['Provider'] = $_.ProviderName
        $dataRow['TimeCreated'] = $_.TimeCreated
        $dataRow['Event'] = $_.Id
        $dataRow['Level'] = $_.LevelDisplayName
        $dataRow['User'] = $user
        $dataRow['Task'] = $_.TaskDisplayName
        $dataRow['Message'] = $_.Message
        $dataTable.Rows.Add($dataRow)
    }

    if ($dataTable.Rows.Count -gt 0) {
        Write-Host "$Computer $LogName ($($dataTable.Rows.Count))"
        Write-SqlTableData -ServerInstance $SqlServer -DatabaseName $SqlDatabase -SchemaName "dbo" -TableName $SqlTable -InputData $dataTable -ProgressAction Ignore
        Write-Host "Data bulk inserted successfully!" -ForegroundColor Green
    }
}
catch {
    Write-Error "Error during bulk insert for $LogName on $Computer : $($_.Exception.Message)"
}
finally {
    if ($dataTable -is [System.IDisposable]) {
        $dataTable.Dispose()
    }
    $dataTable = $null
}