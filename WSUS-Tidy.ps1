[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")

$firstdayofmonth = [datetime] ([string](get-date).AddMonths(-1).month + "/1/" + [string](get-date).year)
$DomainName = "."+ $env:USERDNSDOMAIN
$dateText = (Get-Date).ToString('MM-dd-yyyy_hh-mm-ss')

# Create empty arrays to contain collected data.
$UpdateStatus = @()
$SummaryStatus = @()		

# For WSUS servers catering servers
$WSUSServers = ("wsus-pcs","wsus01-com","wsus-servers","EMIS-SPOKE-3","EMIS-SPOKE-4","EMIS-SPOKE-5","EMIS-SPOKE-6","EMIS-SPOKE-7","EMIS-SPOKE-8","EMIS-SPOKE-9")

$a0 = ($WSUSServers | measure).count
$b0 = 0

$thisDir = try{ Split-Path -Parent $MyInvocation.MyCommand.Path} Catch {"C:\wsus-reports\transcripts\"}
$logFile = "WSUSDeadCleanUP_$dateText.txt"
$allComp = (Get-ADComputer -Filter *) + (Get-ADComputer -Filter * -SearchBase "DC=sticl,DC=xsthealth,DC=nhs,DC=uk" -server "sticl.xsthealth.nhs.uk")
$allCompCount = ($allComp).count
Start-Transcript -Path $thisDir\$logFile


ForEach ($WSUSServer in $WSUSServers) {		
        write-host "Connecting to $WSUSServer ..."	-foregroundcolor Green
        $b0 = $b0+1
		
    try {
        
		Try {
		 $WSUS = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($WSUSServer,$false,8530)
	    }
		Catch {
		 $WSUS = [Microsoft.UpdateServices.Administration.AdminProxy]::getUpdateServer($WSUSServer,$false,80)
		}
		write-host "Connected and Fetching all computers connecting to $WSUSServer ..." -NoNewline -ForegroundColor Gray
		$WSUSMCs = $WSUS.getComputerTargets()
        Write-Verbose "done."
        $WSUSMCsCount = ($WSUSMCs).count
        Write-Verbose "Hosts in $WSUSServer : $WSUSMCsCount"
        Write-verbose "Checking $WSUSServer Hosts vs Active Directory ..."
        $Deadcomp = $WSUSMCs | where {($_.FullDomainName) -notin ($allComp.dnshostname)}
        $deadcompcount = ($deadcomp).count
        Write-Verbose "done."
        Write-verbose "Macines in AD = $AllCompCount, Machines in $WSUSServer = $WSUSMCsCount, Machines in $WSUSServer not in AD = $DeadcompCount"
        if ($Deadcomp.count  -ne 0) {
         write-host "$($Deadcomp.count) computers are Not Active" -ForegroundColor Red
         Write-host $Deadcomp.FullDomainName -Separator "`n`r" -ForegroundColor white
         $del = Read-Host -prompt "Do You Wish to Delete ALL wsus hosts not in AD [Y/n]"
         if (($del -eq "Y") -or($del -eq "Y*") -or ($AutoDelete)){
          write-Verbose "Deleting $deadcount Machines from $wsusserver ..."
          $Deadcomp.delete()
          Write-verbose "done."
          write-Host "$deadcount Machines removed from $wsusserver"
         }
        }
        Else {
         Write-Host "All Active" -ForegroundColor Gray
         }
        }
		catch [Exception] {
				write-host $_.Exception.GetType().FullName -foregroundcolor Red
				write-host $_.Exception.Message -foregroundcolor Red
                continue;
		}
	}
				
Stop-Transcript
notepad $thisDir\$logFile