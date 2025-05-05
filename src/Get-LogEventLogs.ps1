using namespace System.Data.SqlClient;

[CmdletBinding()]
param (
    [Parameter()]
    [System.String] $Computer = [Environment]::MachineName,

    [Parameter()]
    [System.String] $LogName = 'Security',

    [Parameter()]
    [System.String] $FilterXPath = "*",

    [Parameter()]
    [System.String] $SqlServer = '(localdb)\MSSQLLocalDB',

    [Parameter()]
    [System.String] $SqlDatabase = 'EventLogs',

    [Parameter()]
    [System.String] $SqlTable = 'EventData'

)

# Clear-Host;

$sdate = (Get-Date).AddHours(-1).AddMinutes( - ($date.Minute)).AddSeconds( - ($date.Second)).AddMilliseconds( - ($date.Millisecond));
$edate = $sdate.AddHours(1);

$sdatefilter = $sdate.ToUniversalTime().ToString("o");
$edatefilter = $edate.ToUniversalTime().ToString("o");

$FilterXPath = "*[System[TimeCreated[@SystemTime>='$sdatefilter' and @SystemTime<='$edatefilter']]]"

$dataTable = New-Object System.Data.DataTable

$dataTable.Columns.Add('Record', [long]) | Out-Null;
$dataTable.Columns.Add('MachineName', [String]) | Out-Null;
$dataTable.Columns.Add('Log', [String]) | Out-Null;
$dataTable.Columns.Add('Provider', [String]) | Out-Null;
$dataTable.Columns.Add('TimeCreated', [DateTime]) | Out-Null;
$dataTable.Columns.Add('Event', [Int32]) | Out-Null;
$dataTable.Columns.Add('Level', [String]) | Out-Null;
$dataTable.Columns.Add('User', [String]) | Out-Null;
$dataTable.Columns.Add('Task', [String]) | Out-Null;
$dataTable.Columns.Add('Message', [String]) | Out-Null;

Get-WinEvent -ComputerName $Computer -LogName $LogName -FilterXPath $FilterXPath -ErrorAction SilentlyContinue | 
Select-Object MachineName, LogName, ProviderName, RecordId, TimeCreated, Id, LevelDisplayName, UserId, TaskDisplayName, Message | 
Sort-Object MachineName, LogName, ProviderName, RecordId | 
ForEach-Object {
    
    $user = $null;
    if ($null -ne $_.UserId) {
        $user = $_.UserId.Translate([System.Security.Principal.NTAccount]).Value
    }

    $dataRow = $dataTable.NewRow();
        
    $dataRow['Record'] = [Convert]::ToInt64($_.RecordId); # long?
    $dataRow['MachineName'] = $_.MachineName; # string
    $dataRow['Log'] = $_.LogName; # string
    $dataRow['Provider'] = $_.ProviderName; # string
    $dataRow['TimeCreated'] = $_.TimeCreated; # datetime?
    $dataRow['Event'] = $_.Id; # int
    $dataRow['Level'] = $_.LevelDisplayName; # string
    $dataRow['User'] = $user; # string?
    $dataRow['Task'] = $_.TaskDisplayName; # string
    $dataRow['Message'] = $_.Message; # string
        
    $dataTable.Rows.Add($dataRow);
}
        
# $datatable | Get-Member
        
try {
    if ($null -ne $dataTable -and $dataTable.Rows.Count -gt 0) {
        Write-Host "$Computer $LogName ($($dataTable.Rows.Count))";
        
        Write-SqlTableData `
            -ServerInstance $SqlServer `
            -DatabaseName $SqlDatabase `
            -SchemaName "dbo" `
            -TableName $SqlTable `
            -InputData $dataTable `
            -ProgressAction Ignore
        
        Write-Host "Data bulk inserted successfully!" -f Green
    }
}
catch {
    Write-Error "Error during bulk insert: $($_.Exception.Message)"
}
finally {
    $dataTable = $null;
}