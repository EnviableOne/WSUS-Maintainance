[cmdletbinding()]
Param()
[void][reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration")

$DomainName = "."+ $env:USERDNSDOMAIN
$dateText = (Get-Date).ToString('MM-dd-yyyy_hh-mm-ss')

# Create empty arrays to contain collected data.
$UpdateStatus = @()
$SummaryStatus = @()		

# WSUS servers in environment
$WSUSServers = ("wsus-pcs","wsus-com","wsus-servers","WSUS-3","WSUS-4","WSUS-5","WSUS-6","WSUS-7","WSUS-8","WSUS-9")

$ServerCount = ($WSUSServers | measure).count
$CurrentServer = 0

$thisDir = try{ Split-Path -Parent $MyInvocation.MyCommand.Path} Catch {"C:\wsus-reports\transcripts\"}
$logFile = "WSUSDeadCleanUP_$dateText.txt"
$allComp = (Get-ADComputer -Filter *) + (Get-ADComputer -Filter * -SearchBase "DC=contoso,DC=uk" -server "contoso.uk")
$allCompCount = ($allComp).count
Start-Transcript -Path $thisDir\$logFile

ForEach ($WSUSServer in $WSUSServers) {		
        $CurrentServer++
        write-host "Connecting to $WSUSServer ( Server $CurrentServer of $ServerCount) ..."	-foregroundcolor Green
	
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
        if ($DeadcompCount  -ne 0) {
         write-host "$DeadcompCount computers are Not Active" -ForegroundColor Red
         Write-host $Deadcomp.FullDomainName -Separator "`n`r" -ForegroundColor white
         $del = Read-Host -prompt "Do You Wish to Delete ALL wsus hosts not in AD [Y/n]"
         if (($del -eq "Y") -or($del -eq "Y*") -or ($AutoDelete)){
          write-Verbose "Deleting $DeadcompCount Machines from $wsusserver ..."
          $Deadcomp.delete()
          Write-verbose "done."
          write-Host "$DeadcompCount Machines removed from $wsusserver"
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
