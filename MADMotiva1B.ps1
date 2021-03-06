#################################################################

$ScriptDir = Split-Path -Path $MyInvocation.MyCommand.Definition -Parent
$inputFile = $ScriptDir + "\Input"
$getAllCSV = Get-ChildItem -Path $inputFile -Recurse -Filter *.csv
$ReportFile = New-Item "$ScriptDir\Report\MADMotiva_1B_Report_$(Get-Date -Format yyymmddhhmm).csv" -type file -Force -value "Alias/Display Name, Status, Primary Email(OLD), Secondary Email(OLD), Primary Email(NEW), Secondary Email(NEW), Error`n"
$counter = 0

#################################################################

function log
{
    param (
    [string]$alias,
    [string]$status,
    [string]$OldPrimary,
    [string]$OldSecondary,
    [string]$NewPrimary,
    [string]$NewSecondary,
    [string]$error)
    
    try
    {
        $wr = Write-Output ("{0},{1},{2},{3},{4},{5},{6}" -f $alias, $status, $OldPrimary, $OldSecondary, $NewPrimary, $NewSecondary, $error)
        $wr | Out-File $ReportFile -Append
    }
    catch{
       [system.exception]"Status: Cannot append data into the output file !`n"
    }
}

Write-Output "`nSTART"

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
            #Check primary address
            $primaryEmail = Get-Mailbox $alias.alias -ErrorAction Stop | Select-Object PrimarySmtpAddress
        }
        catch
        {
            Write-Output "`n`nStatus`n`n- NOT FOUND !"
            log -alias $alias.alias -status "NOT FOUND" -OldPrimary "N/A" -OldSecondary "N/A" -NewPrimary "N/A" -NewSecondary "N/A" -error "N/A"
            Continue
        }
        
        
        #Check Primary Email is Empty
        if([string]::IsNullOrEmpty($primaryEmail.PrimarySmtpAddress))
        {
            # SKIP ! No primary email.
            Write-Output "`n`nStatus`n`n- SKIP ! No primary email."
            log -alias $alias.alias -status "SKIP. NO PRIMARY EMAIL." -OldPrimary "N/A" -OldSecondary "N/A" -NewPrimary "N/A" -NewSecondary "N/A" -error "N/A"
        }
        else
        {
            if($primaryEmail.PrimarySmtpAddress.Domain -like 'motivaent.sopt.com')
            {                        
                #Check secondary email
                $secondaryEmail = Get-Mailbox $alias.alias -ErrorAction Stop | Select-Object @{Name=“SecondaryEmailAddresses”;Expression={$_.EmailAddresses | Where-Object {$_.PrefixString -ceq “smtp”} | ForEach-Object {$_.SmtpAddress}}}
                if([string]::IsNullOrEmpty($secondaryEmail.SecondaryEmailAddresses))
                {
                    # SKIP ! No secondary email.
                    Write-Output "`n`nStatus`n`n- SKIP ! No secondary email."
                    log -alias $alias.alias -status "SKIP. NO SECONDARY EMAIL." -OldPrimary "N/A" -OldSecondary "N/A" -NewPrimary "N/A" -NewSecondary "N/A" -error "N/A"
                }
                else
                {
                    if($secondaryEmail.SecondaryEmailAddresses -like '*@sopt.shell.com')
                    {
                        Write-Output "`n`nStatus`n`n- SWAPPING EMAIL..."
                        try
                        {
                            $PE = $primaryEmail.PrimarySmtpAddress
                            $SE = $secondaryEmail.SecondaryEmailAddresses
                            Set-Mailbox $alias.alias -ErrorAction Stop -EmailAddresses SMTP:$SE,smtp:$PE
                            Write-Output "- SUCCESS."
                            log -alias $alias.alias -status "SWAP" -OldPrimary "$PE" -OldSecondary "$SE" -NewPrimary "$SE" -NewSecondary "$PE" -error "N/A"
                        }
                        catch
                        {
                            $ErrorMessage = $_.Exception.Message -replace ',', ""
                            Write-Output "- FAIL ! $ErrorMessage"
                            log -alias $alias.alias -status "FAIL" -OldPrimary "N/A" -OldSecondary "N/A" -NewPrimary "N/A" -NewSecondary "N/A" -error "$ErrorMessage"
                            Continue
                        }
                        
                    }
                    else
                    {
                        # SKIP ! Secondary Email is NOT SHELL email.
                        Write-Output "`n`nStatus`n`n- SKIP ! Secondary email is NOT SHELL email."
                        log -alias $alias.alias -status "SKIP. SECONDARY EMAIL IS NOT SHELL EMAIL." -OldPrimary "N/A" -OldSecondary "N/A" -NewPrimary "N/A" -NewSecondary "N/A" -error "N/A"
                    }
                }
            }
            else 
            {
                # SKIP ! Primary Email is NOT MOTIVA email.
                Write-Output "`n`nStatus`n`n- SKIP ! Primary email is NOT MOTIVA email."
                log -alias $alias.alias -status "SKIP. PRIMARY EMAIL IS NOT MOTIVA EMAIL." -OldPrimary "N/A" -OldSecondary "N/A" -NewPrimary "N/A" -NewSecondary "N/A" -error "N/A"
            }
        } 
    }
}

Write-Output "`nEND`n"
