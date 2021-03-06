#################################################################

$ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$inputFile = $ScriptDir + "\Input"
$getAllCSV = Get-ChildItem -Path $inputFile -Recurse -Filter *.csv
$ReportFile = New-Item "$ScriptDir\Report\MADMotiva_1A_Report_$(Get-Date -Format yyymmddhhmm).csv" -type file -Force -value "Alias/Display Name, Status, Activity, Primary Email, Secondary Email, Error`n"
$counter = 0

#################################################################

function checkEmailExisting
{
    param (
    [string]$email,
    [string]$firstname,
    [string]$lastname)

    $csvFilePath = $ScriptDir + "\Temp\*.csv"
    $importCSV = import-csv -Header MailNickName -Path $csvFilePath
    
    $flag = 0
    while($flag -eq 0)
    {
        foreach($mailList in $importCSV)
        {   
            if($mailList -match $email)
            {
                $lastname = $lastname.Substring(0,$lastname.Length-1)
                $email = "$firstname.$lastname@shell.com"
            }
            else
            {
                $flag = 1
            }
        } 
    }
    return "$email"
}

function log
{
    param (
    [string]$alias,
    [string]$status,
    [string]$activity,
    [string]$primaryEmailLog,
    [string]$secondaryEmailLog,
    [string]$error)
    
    try
    {
        $wr = Write-Output ("{0},{1},{2},{3},{4},{5}" -f $alias, $status, $activity, $primaryEmailLog, $secondaryEmailLog, $error)
        $wr | Out-File $ReportFile -Append
    }
    catch{
       [system.exception]"Status: Cannot append data into the output file !`n"
    }
}

Write-Output "`nSTART`n`nPreparing email list file...`n"

Get-Recipient -resultsize "Unlimited" | Select -ExpandProperty EmailAddresses | Select SmtpAddress | Out-File "$ScriptDir\Temp\AllEmailList_$(Get-Date -Format yyymmddhhmmss).csv"

Write-Output "DONE !"


foreach($csv in $getAllCSV)
{
    $csvFilePath = $inputFile + "\" + $csv
    
    try
    {
        $importCSV = import-csv -Header alias -Path $csvFilePath
    }
    catch
    {
        Write-Output "No .CSV File Found !"
    }
    
    foreach($alias in $importCSV)
    {   
        $counter++
        Write-Host -NoNewline "`n`n---------------------------`n"
        Write-Host -NoNewline $counter "|" $alias.alias "`n"
        try
        {
            # CHECK MAILBOX AVAILABILITY
            $primaryEmail = Get-Mailbox $alias.alias -ErrorAction Stop | Select-Object PrimarySmtpAddress
        }
        catch
        {
            Write-Output "`n`nStatus`n`n- NOT FOUND !"
            log -alias $alias.alias -status "NOT FOUND" -activity "Search Mailbox" -primaryEmailLog "N/A" -secondaryEmailLog "N/A" -error "N/A"
            Continue
        }
        
        # CHECK PRIMARY EMAIL IS EMPTY
        if([string]::IsNullOrEmpty($primaryEmail.PrimarySmtpAddress))
        {
            $getFirstName = Get-Mailbox $alias.alias | Get-User | Select-Object firstname
            $getLastName = Get-Mailbox $alias.alias | Get-User | Select-Object lastname
            $newEmail = "$($getFirstName.FirstName).$($getLastName.LastName)@sopt.shell.com"
            
            $checkMail = checkEmailExisting -email "$newEmail" -firstname "$($getFirstName.FirstName)" -lastname "$($getLastName.LastName)"
            Write-Output "`n`nStatus`n`n- FOUND ! No primary email. Creating new email !"
            
            # CREATE NEW SHELL EMAIL
            try
            {
                Set-Mailbox $alias.alias -EmailAddresses SMTP:$checkMail -ErrorAction Stop
                Write-Output "- Email Created ! SUCCESS."
                log -alias $alias.alias -status "SUCCESS" -activity "Primary email not exist. Create primary email." -primaryEmailLog "$checkMail" -secondaryEmailLog "N/A" -error "N/A"
            }
            catch
            {
                $ErrorMessage = $_.Exception.Message -replace ',', ""
                Write-Output "- FAIL ! $ErrorMessage"
                log -alias $alias.alias -status "FAIL" -activity "Primary email not exist. Trying to create primary email." -primaryEmailLog "N/A" -secondaryEmailLog "N/A" -error "$ErrorMessage"
                Continue
            }
        }
        else
        {
            if($primaryEmail.PrimarySmtpAddress.Domain -like 'motivaent.sopt.com')
            {                       
                # CHECK SECONDARY EMAIL AVAILABILITY
                
                $secondaryEmail = Get-Mailbox $alias.alias -ErrorAction Stop | Select-Object @{Name=“SecondaryEmailAddresses”;Expression={$_.EmailAddresses | Where-Object {$_.PrefixString -ceq “smtp”} | ForEach-Object {$_.SmtpAddress}}}
                
                if([string]::IsNullOrEmpty($secondaryEmail.SecondaryEmailAddresses))
                { 
                    $getFirstName = Get-Mailbox $alias.alias | Get-User | Select-Object firstname
                    $getLastName = Get-Mailbox $alias.alias | Get-User | Select-Object lastname
                    $newEmail = "$($getFirstName.FirstName).$($getLastName.LastName)@sopt.shell.com"
                    
                    $PE = $primaryEmail.PrimarySmtpAddress
                    
                    $checkMail = checkEmailExisting -email "$newEmail" -firstname "$($getFirstName.FirstName)" -lastname "$($getLastName.LastName)"
                    Write-Output "`n`nStatus`n`n- FOUND ! Primary email is MOTIVA. No secondary email. Creating new secondary email !"
                    
                    # CREATE NEW SHELL EMAIL
                    try
                    {
                        Set-Mailbox $alias.alias -EmailAddresses @{Add=$checkMail} -ErrorAction Stop
                        Write-Output "- Email Created ! SUCCESS."
                        log -alias $alias.alias -status "SUCCESS" -activity "Primary email is MOTIVA email. Second email not exist. Create second email." -primaryEmailLog "$PE" -secondaryEmailLog "$checkMail" -error "N/A"
                    }
                    catch
                    { 
                        $ErrorMessage = $_.Exception.Message -replace ',', ""
                        Write-Output "- FAIL ! $ErrorMessage"
                        log -alias $alias.alias -status "FAIL" -activity "Primary email is MOTIVA email. Second email not exist. Trying to create second email." -primaryEmailLog "$PE" -secondaryEmailLog "N/A" -error "$ErrorMessage"
                        Continue
                    }
                }
                else
                {
                    if($secondaryEmail.SecondaryEmailAddresses -like '*@sopt.shell.com')
                    { 
                        # DO NOTHING: SECONDARY EMAIL IS A SHELL EMAIL
                        Write-Output "`n`nStatus`n`n- SKIP ! Primary email is MOTIVA. Secondary email is SHELL email. !"
                        $PE = $primaryEmail.PrimarySmtpAddress
                        $SE = $secondaryEmail.SecondaryEmailAddresses
                        log -alias $alias.alias -status "SKIP" -activity "Primary email is MOTIVA email. Second email is SHELL email." -primaryEmailLog "$PE" -secondaryEmailLog "$SE" -error "N/A"
                    }
                    else
                    {
                        $getFirstName = Get-Mailbox $alias.alias | Get-User | Select-Object firstname
                        $getLastName = Get-Mailbox $alias.alias | Get-User | Select-Object lastname
                        $newEmail = "$($getFirstName.FirstName).$($getLastName.LastName)@sopt.shell.com"
                        
                        $PE = $primaryEmail.PrimarySmtpAddress
                        
                        $checkMail = checkEmailExisting -email "$newEmail" -firstname "$($getFirstName.FirstName)" -lastname "$($getLastName.LastName)"
                        Write-Output "`n`nStatus`n`n- FOUND ! Primary email is MOTIVA. Secondary email is not SHELL email. Creating new email !"
                        
                        # CREATE NEW SHELL EMAIL
                        try
                        {
                            Set-Mailbox $alias.alias -EmailAddresses @{Add=$checkMail} -ErrorAction Stop
                            Write-Output "- Email Created ! SUCCESS."
                            log -alias $alias.alias -status "SUCCESS" -activity "Primary email is MOTIVA email. Second email is not SHELL email. Create new email." -primaryEmailLog "$PE" -secondaryEmailLog "$checkMail" -error "N/A"
                        }
                        catch
                        {
                        
                            $ErrorMessage = $_.Exception.Message -replace ',', ""
                            Write-Output "- FAIL ! $ErrorMessage"
                            log -alias $alias.alias -status "FAIL" -activity "Primary email is MOTIVA email. Second email is not SHELL email. Trying to create new email." -primaryEmailLog "$PE" -secondaryEmailLog "$checkMail" -error "$ErrorMessage"
                            Continue
                        }
                    }
                }
            }
            else
            {
                # DO NOTHING: PRIMARY EMAIL IS NOT MOTIVA EMAIL
                Write-Output "`n`nStatus`n`n- SKIP ! Primary email is NOT MOTIVA."
                $PE = $primaryEmail.PrimarySmtpAddress
                log -alias $alias.alias -status "SKIP" -activity "Primary email is not MOTIVA email." -primaryEmailLog "$PE" -secondaryEmailLog "N/A" -error "N/A"
            }
        } 
    }
}

remove-item $ScriptDir\Temp\*.csv -force

Write-Output "`nEND`n"
