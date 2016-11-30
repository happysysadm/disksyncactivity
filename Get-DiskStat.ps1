 <#
.Synopsis
   Monitors physical disk activity per bay during sync activities
.DESCRIPTION
   Monitors physical disk activity during a sync and highlights the disks that are active reading or writing bytes and the bay they belong to
.EXAMPLE
   Get-DiskStat -SourceComputer srv1 -SourceStorageBayName 'HPE 3PAR' -SourceDiskPattern '\(2\)|\(14\)' -DestinationComputer srv2 -DestinationStorageBayName 'HP XP128' -DestinationDiskPattern '\(7\)|\(10\)' -Refresh -Frequency 2 -Repeat 10
.EXAMPLE
   Get-DiskStat -SourceComputer srv1 -SourceStorageBayName 'HPE 3PAR' -SourceDiskPattern '\(2\)|\(14\)' -DestinationComputer srv2 -DestinationStorageBayName 'HP XP128' -DestinationDiskPattern '\(7\)|\(10\)' -Refresh -ShowCpu
.EXAMPLE
   Get-DiskStat -SourceComputer srv1 -SourceStorageBayName 'HPE 3PAR' -SourceDiskPattern '\(2\)|\(14\)' -DestinationComputer srv2 -DestinationStorageBayName 'HP XP128' -DestinationDiskPattern '\(7\)|\(10\)' -Refresh -ShowCpu -ShowQueue
.EXAMPLE
   Get-DiskStat -SourceComputer srv1 -SourceStorageBayName 'HPE 3PAR' -SourceDiskPattern '\(2\)|\(14\)' -DestinationComputer srv2 -DestinationStorageBayName 'HP XP128' -DestinationDiskPattern '\(7\)|\(10\)' -Refresh -ShowCpu -ShowQueue -Credential (Get-Credential)
.EXAMPLE
   Get-DiskStat -sc srv1 -sbn 'HPE 3PAR' -sdp '\(2\)|\(14\)' -dc srv2 -dbn 'HP XP128' -ddp '\(7\)|\(10\)' -R -C -Q -Cred (Get-Credential) -F 1 -rep 1000
.AUTHOR
   Carlo MANCINI
#>
function Get-DiskStat
{
    Param
    (
        # Source computer for the sync
        [Parameter(Mandatory=$true,Position=0)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("sc")]
        $SourceComputer,

        # Source bay name for the sync
        [Parameter(Mandatory=$true,Position=1)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("sbn")]
        $SourceStorageBayName,

        # Source disk pattern for the sync
        [Parameter(Mandatory=$true,Position=2)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("sdp")]
        $SourceDiskPattern,

        # Destination computer for the sync
        [Parameter(Mandatory=$true,Position=3)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("dc")]
        $DestinationComputer,

        # Destination bay name for the sync
        [Parameter(Mandatory=$true,Position=4)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("dbn")]
        $DestinationStorageBayName,

        # Destination disk pattern for the sync
        [Parameter(Mandatory=$true,Position=5)]
        [ValidateNotNull()]
        [ValidateNotNullOrEmpty()]
        [Alias("ddp")]
        $DestinationDiskPattern,

        # Clear the screen between each execution
        [Parameter(Position=6)][Alias("r")][Switch]$Refresh,

        # Show Active and Idle CPU counters
        [Parameter(Position=7)][Alias("c")][Switch]$ShowCpu,

        # Show disk queue for selected disks
        [Parameter(Position=8)][Alias("q")][Switch]$ShowQueue,

        # Specifies a user account that has permission to perform this action
        [Parameter(Mandatory=$false,Position=9)]
        [System.Management.Automation.PSCredential]
        [System.Management.Automation.Credential()]
        $Credential = [System.Management.Automation.PSCredential]::Empty,

        # Frequency of the polling in seconds
        [Parameter(Position=10)]
        [Alias("f")]
        $Frequency = 10,

        # Total number of polling to perform
        [Parameter(Position=11)]
        [Alias("rep")]
        $Repeat = 10

    )
    
    Try { 
    
        Test-Connection $SourceComputer,$DestinationComputer -Count 1 -ErrorAction Stop | Out-Null
        
        }
    
    Catch {
    
        Throw "At least one of the target servers is not reachable. Exiting."
        
        }

    $CounterList = '\PhysicalDisk(*)\Disk Read Bytes/sec','\PhysicalDisk(*)\Disk Write Bytes/sec','\PhysicalDisk(*)\Current Disk Queue Length','\Processor(_Total)\% Idle Time','\Processor(_Total)\% Processor Time'

    1..$Repeat | % {

        $SourceCounterValue = (Get-Counter $CounterList -ComputerName $SourceComputer).countersamples

        if($DestinationComputer -eq $SourceComputer) {

            $DestinationCounterValue = $SourceCounterValue

            $SameHost = $True

            }

        else {
        
            $DestinationCounterValue = (Get-Counter $CounterList -ComputerName $DestinationComputer).countersamples

            }

        if($Refresh) {Clear-Host}

        if($ShowCpu) {

                    "$SourceComputer CPU Activity & Idle"
                    
                    $SourceCounterValue | ? {$_.path -match 'processor'} | % {
    
                            Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $([math]::round($_.cookedvalue)).tostring().padright(10)
                            
                            }

                    if(!$SameHost) {
                    
                        "$DestinationComputer CPU Activity & Idle"
                    
                        $DestinationCounterValue | ? {$_.path -match 'processor'} | % {
    
                            Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $([math]::round($_.cookedvalue)).tostring().padright(10)
                            
                            }
                        }

                    }

        if($ShowQueue) {

            "$SourceStorageBayName Storage Bay Disk Queue on $SourceComputer"

            $SourceCounterValue | ? {($_.path -match $SourceDiskPattern) -and ($_.path -match 'queue')} | % {
    
                    if($_.cookedvalue -gt 0) {
                    
                        Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $_.cookedvalue.tostring().padright(10) -ForegroundColor Green
                            
                        }
    
                    else {
                    
                        Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $_.cookedvalue.tostring().padright(10) -ForegroundColor White
                        
                        }
                    
                    }

            "$DestinationStorageBayName Storage Bay Disk Queue on $DestinationComputer"

            $DestinationCounterValue | ? {($_.path -match $DestinationDiskPattern) -and ($_.path -match 'queue')} | % {
    
                    if($_.cookedvalue -gt 0) {
                    
                        Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $_.cookedvalue.tostring().padright(10) -ForegroundColor Green
                            
                        }
    
                    else {
                    
                        Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $_.cookedvalue.tostring().padright(10) -ForegroundColor White
                        
                        }
                    
                    }

            }

　
        "$SourceStorageBayName Read stats on $SourceComputer"

        $SourceCounterValue | ? {($_.path -match $SourceDiskPattern) -and ($_.path -match 'read')} | % {
    
            if($_.cookedvalue -gt 0) {
            
                Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $([math]::round($_.cookedvalue)).tostring().padright(10) -ForegroundColor Green
                
                }
    
            else {
            
                Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $([math]::round($_.cookedvalue)).tostring().padright(10) -ForegroundColor White
                
                }
            
            }

        "$SourceStorageBayName Write stats on $SourceComputer"

        $SourceCounterValue | ? {($_.path -match $SourceDiskPattern) -and ($_.path -match 'write')} | % {
    
            if($_.cookedvalue -gt 0) {
            
                Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $([math]::round($_.cookedvalue)).tostring().padright(10) -ForegroundColor Green
                
                }
    
            else {
            
                Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $([math]::round($_.cookedvalue)).tostring().padright(10) -ForegroundColor White
                
                }
            
            }

        "$DestinationStorageBayName Read stats on $DestinationComputer"

        $DestinationCounterValue | ? {($_.path -match $DestinationDiskPattern) -and ($_.path -match 'read')} | % {
    
            if($_.cookedvalue -gt 0) {
            
                Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $([math]::round($_.cookedvalue)).tostring().padright(10) -ForegroundColor Green
                
                }
    
            else {
            
                Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $([math]::round($_.cookedvalue)).tostring().padright(10) -ForegroundColor White
                
                }
            
            }

        "$DestinationStorageBayName Write stats on $DestinationComputer"

        $DestinationCounterValue | ? {($_.path -match $DestinationDiskPattern) -and ($_.path -match 'write')} | % {
    
            if($_.cookedvalue -gt 0) {
            
                Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $([math]::round($_.cookedvalue)).tostring().padright(10) -ForegroundColor Green
                
                }
    
            else {
            
                Write-Host $_.path.padright(65)`t $_.InstanceName.padright(5)`t $([math]::round($_.cookedvalue)).tostring().padright(10) -ForegroundColor White
                
                }
            
            }

        Start-Sleep -Seconds $frequency

        }    

} 
