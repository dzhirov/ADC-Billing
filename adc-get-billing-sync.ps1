#!PS
#timeout=60000
#Gets the group(s) that match the filter and collect all members of the matching group(s)
$Users = Get-ADGroup -Filter { name -like "*rdsh*" -or name -like "*horizon*" -or name -like "r[0-9] users" -or name -like "app_*" -or name -like "Workstation*"} | Get-ADGroupMember | Select-Object -ExpandProperty SamAccountName
[INT]$CountBilled = 0
[INT]$CountTotal = 0
[INT]$CountNonBilled = 0
[INT]$CountSkipped = 0
$ArraySkipped = New-Object System.Collections.ArrayList
$SkippedNames = @(
    "admin",
    "test",
    "user",
    "guest"
)
$Billed = New-Object System.Collections.ArrayList
$NonBilled = New-Object System.Collections.ArrayList
#for every member of the group(s) add 1 to the count total and add 1 to the total of the appropriate count based on if the account is enabled or disabled
foreach ($User in $Users)
{
    $CountTotal++
    #Filters all AD users and compare them to the SamAccountName of the user to see if it exists
    try {
        $Account = Get-ADUser -Properties SamAccountName, Enabled, employeeType -Filter { SamAccountName -eq $User }
        #Gets every group for each user found matching original criteria
        #$Groups = Get-ADPrincipalGroupMembership -Identity $User
        if ($Account)
        {
            if (-not $Account.Enabled -or $Account.employeeType -eq "core")
            {
                $NonBilled.Add($Account.SamAccountName) | Out-Null
                $CountNonBilled++
            }
            elseif ($Account.SamAccountName -match ($SkippedNames -join '|') -and $Account.employeeType -ne "Cloud")
            {
                $NonBilled.Add($Account.SamAccountName) | Out-Null
                $CountNonBilled++
            }
            else
            {
                $Billed.Add($Account.SamAccountName) | Out-Null
                $CountBilled++
            }
        }
        #If the account fails to be found print the below
        else
        {
            [pscustomobject]@{
                SamAccountName = $User
                Enabled        = 'Account Not Found'
            }
            $CountSkipped++
        }
    }
    catch {
        Write-Warning "Error processing user $User"
        Write-Warning $_.Exception.Message
        $CountSkipped++
    }
}
$NonBilled = $NonBilled | sort | Select-Object -Unique
$Billed = $Billed | sort | Select-Object -Unique | Where-Object { $NonBilled -notcontains $_ }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# Get client information
$clientName = $env:COMPUTERNAME
$currentDate = Get-Date -Format "yyyy-MM-ddTHH:mm:ssZ"

# Original event data for webhook (keep this for backward compatibility)
$event = @{
    Billable_User_Count = $Billed.Count
    Billable_Users      = $Billed
    Client              = $clientName
    Non_Billable_Users  = $NonBilled.Count
    Users_Not_Billed    = $NonBilled
    Date                = Get-Date
}
$json = $event | ConvertTo-Json
$json

# Send data to original webhook (keep original functionality)
$null = Invoke-RestMethod -Uri 'https://webhook.site/adeptbilling' -Method Post -Body $json

# Supabase configuration - UPDATE THESE VALUES
$supabaseUrl = "https://your-project-id.supabase.co"
$supabaseKey = "your-supabase-api-key"  # Use anon key or service role key depending on your security needs

# Create data for billing_data table
$billingData = @{
    client_name = $clientName
    billable_user_count = $Billed.Count
    non_billable_user_count = $NonBilled.Count
    collection_date = $currentDate
}

# Set headers for Supabase API
$headers = @{
    "apikey" = $supabaseKey
    "Authorization" = "Bearer $supabaseKey"
    "Content-Type" = "application/json"
    "Prefer" = "return=representation"
}

try {
    # Insert into billing_data table and get the ID
    $billingResponse = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/billing_data" -Method Post -Headers $headers -Body ($billingData | ConvertTo-Json)
    $billingId = $billingResponse.id
    
    Write-Host "Successfully inserted billing record with ID: $billingId"
    
    # Process billable users
    foreach ($user in $Billed) {
        $userData = @{
            billing_id = $billingId
            username = $user
            user_type = "billable"
        }
        
        # Insert user data
        $null = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/billing_users" -Method Post -Headers $headers -Body ($userData | ConvertTo-Json)
    }
    
    # Process non-billable users
    foreach ($user in $NonBilled) {
        $userData = @{
            billing_id = $billingId
            username = $user
            user_type = "non_billable"
        }
        
        # Insert user data
        $null = Invoke-RestMethod -Uri "$supabaseUrl/rest/v1/billing_users" -Method Post -Headers $headers -Body ($userData | ConvertTo-Json)
    }
    
    Write-Host "Successfully inserted all user data for client: $clientName"
}
catch {
    Write-Warning "Error sending data to Supabase:"
    Write-Warning $_.Exception.Message
    
    if ($_.Exception.Response) {
        $responseBody = $null
        try {
            $reader = New-Object System.IO.StreamReader($_.Exception.Response.GetResponseStream())
            $responseBody = $reader.ReadToEnd()
            $reader.Close()
        }
        catch {}
        
        if ($responseBody) {
            Write-Warning "Response: $responseBody"
        }
    }
}