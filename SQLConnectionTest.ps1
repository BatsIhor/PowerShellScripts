Function Test-SQLConn ()
{
$connectionString = "Data Source=server;User ID=User;Pwd=Pass`$ord;Initial Catalog=Dbname;"
$sqlConn = new-object ("Data.SqlClient.SqlConnection") $connectionString
trap
{
Write-Error "Cannot connect to $Server.";
continue
}
$sqlConn.Open()
if ($sqlConn.State -eq 'Open')
{
$sqlConn.Close();
"Opened successfully."
}
}

Test-SQLConn