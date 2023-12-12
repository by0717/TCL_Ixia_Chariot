##################################################################################
# $Header: //ral_depot/products/IxChariot6.70.27/HwPairAPI/TCL/Statistics.tcl#1 $
# $DateTime: 2008/06/17 13:37:46 $
# $Author: aameling $
#
# $Workfile: Statistics.tcl $
#
#   Copyright © 2003-2006 by IXIA
#   All Rights Reserved.
#
#   Revision Log:
#   10-08-2003  DS  Genesis
#
# Description:
#   This file contains the proc required for stats.
#
###################################################################################
#
#   PRIVATE INTERFACE:
#
#       CleanupStatWatch        clean up the stat watch.
#       CollectMetrics          return packet group metrics for each port.
#       CollectPGStats          collect packet group metrics.
#       CollectStatWatch        collect statWatch metrics.
#       SetupStatWatch          set up the stat watch.
#       StartMetricsPoll        start polling cycle for metrics collection.
#       StopMetricsPoll         stop polling cycle for metrics collection.
#
###################################################################################


########################################################################################
#
# Procedure:   ixChariot::SetupStatWatch
#
# Description: This procedure sets up the stat watch.
#              It is called by StartMetricsPoll in response to the START command.
#
# Argument(s): None.
#
# Returns:
#   NO_ERROR                    : no error occurred
#   STAT_GROUP_PORT_ADD_FAILED  : error adding port to stat group
#   STAT_WATCH_CREATE_FAILED    : error creating watch
#   STAT_WATCH_ADD_PORT_FAILED  : error adding port to watch
#   STAT_WATCH_START_FAILED     : error watching stats
#   STAT_WATCH_ADD_STAT_FAILED  : error adding stats on watch
#
########################################################################################
proc ixChariot::SetupStatWatch {} \
{
    variable enableMetrics
    variable txPortList
    variable rxPortList
    variable kWatchId

    variable statWatchList

    if {$enableMetrics} {
        statWatch setDefault

        # Create a watch with watchId
        if {[statWatch create $kWatchId]} {
            # Error creating statWatch %1
            ReturnStatus STAT_WATCH_CREATE_FAILED $kWatchId
        }

        # Add the ports to the watch with watchId, just get all ports cause it's easier 
        # than setting up one for tx & one for rx.
        foreach watchPort [concat $txPortList $rxPortList] {
            scan $watchPort "%d %d %d" chassisId cardId portId
                if {[statWatch addPort $kWatchId  $chassisId $cardId $portId]} {
                    # Error adding port %1 to statWatch %2.
                    ReturnStatus STAT_WATCH_ADD_PORT_FAILED [getPortId $chassisId $cardId $portId] $kWatchId
                }
        }

        # Add the stats to the watch with watchId
        foreach statItem $statWatchList {
            set statName "stat[string totitle $statItem 0 0]"
            if {[statWatch addStat $kWatchId $statName]} {
                # Error adding %1 to statWatch %2.
                ReturnStatus STAT_WATCH_ADD_STAT_FAILED $statName $kWatchId
            }
        }

        # Start the watch with watchId
        if {[statWatch start $kWatchId]} {
            # Error watching stats on statWatch %1.
            ReturnStatus STAT_WATCH_START_FAILED $kWatchId
        }
    }

    ReturnStatus NO_ERROR

} ;# ixChariot::SetupStatWatch


########################################################################################
#
# Procedure:   ixChariot::CleanupStatWatch
#
# Description: This procedure cleans up the statistics watch.
#
# Argument(s): None.
#
# Returns:
#   NO_ERROR                    : no error occurred
#
########################################################################################
proc ixChariot::CleanupStatWatch {} \
{

    statWatch setDefault
    ReturnStatus NO_ERROR

} ;# ixChariot::CleanupStatWatch


########################################################################################
#
# Procedure:   ixChariot::StartMetricsPoll
#
# Description: This procedure starts the polling cycle for metrics collection.
#              It is called by HandleStats when the START command is received
#              on the stats socket.
#
# Argument(s): sock - statistics socket identifier.
#              pollTime - statistics polling interval, in milliseconds.
#
# Returns:     None.
#
########################################################################################
proc ixChariot::StartMetricsPoll {sock {pollTime 3000}} \
{
    variable enableMetrics
    variable kRetCode

    if {$enableMetrics} {
        catch {SetupStatWatch} retMsg
        if {$retMsg == $kRetCode(NO_ERROR)} {
            CollectMetrics $sock $pollTime
        } \
        else {
            catch {
                puts $sock $retMsg
                flush $sock
            }
            StopMetricsPoll $sock
        }
    }

} ;# ixChariot::StartMetricsPoll


########################################################################################
#
# Procedure:   ixChariot::StopMetricsPoll
#
# Description: This procedure stops the polling cycle for metrics collection.
#              It is called by HandleStats when the STOP command is received
#              on the stats socket.
#
# Argument(s): sock - statistics socket identifier.
#
# Returns:     None.
#
########################################################################################
proc ixChariot::StopMetricsPoll {sock} \
{
    variable enableMetrics

    set enableMetrics $::false
    if [catch {
        puts $sock "********* STOP **********"
        flush $sock
    }] {
        catch {close $sock}
        set ::forever 1
    }
    CleanupStatWatch

} ;# ixChariot::StopMetricsPoll


########################################################################################
#
# Procedure:   ixChariot::CollectMetrics
#
# Description: This procedure cycles through the list of ports & collects PG metrics for
#              each port, then ships the metrics up the socket connection as a tagged
#              name-value pair per each port.
#
# Argument(s): sock - statistics socket identifier.
#              pollTime - statistics polling interval, in milliseconds.
#
# Returns:     None.
#
########################################################################################
proc ixChariot::CollectMetrics {sock pollTime} \
{
    variable enableMetrics

    if {$enableMetrics} {
        if [catch {
            CollectStatWatch $sock
            CollectPGStats $sock
            flush $sock
            after $pollTime [list ixChariot::CollectMetrics $sock $pollTime]
        } retMsg] {
            variable logFile
            if {![catch {open $logFile a} fileId]} {
                puts $fileId "CollectMetrics: $retMsg"
                close $fileId
            }
            StopMetricsPoll $sock
            catch {close $sock}
            set ::forever 1
        }
    }

    return $::TCL_OK

} ;# ixChariot::CollectMetrics


########################################################################################
#
# Procedure:   ixChariot::CollectStatWatch
#
# Description: This procedure collects the statWatch metrics - NOTE:  statWatch is NOT
#              supported for 3.65, so we have to use statGroup gets w/that version.
#
# Argument(s): sock - socket identifier.
#
# Returns:     Throws an exception if an error occurs.
#
########################################################################################
proc ixChariot::CollectStatWatch {sock} \
{
    variable txPortList
    variable rxPortList

    variable enableMetrics
    variable statWatchList

    set statWatchMetrics [list]

    if {$enableMetrics} {
        foreach watchPort [concat $txPortList $rxPortList] {
            scan $watchPort "%d %d %d" chassisId cardId portId
            
            set statString "<$chassisId,$cardId,$portId "
            if {[statList get $chassisId $cardId $portId]} {
                continue
            }
            foreach statItem $statWatchList {
                catch {lappend statString "$statItem,[statList cget -$statItem]"}
            }

            if {[statList getRate $chassisId $cardId $portId]} {
                continue
            }
            foreach statItem $statWatchList {
                set statName "stat[string totitle $statItem 0 0]"
                catch {lappend statString "[format "%sRate" $statName],[statList cget -$statItem]"}
            }
            lappend statString "end>"

            if [catch {puts $sock $statString} retMsg] {
                return -code error "Error writing stats socket: $retMsg"
            }
            #LogEvent $statString
        }
    }

    return $::TCL_OK

} ;# ixChariot::CollectStatWatch


########################################################################################
#
# Procedure:   ixChariot::CollectPGStats
#
# Description: This procedure collects the packet group metrics
#
# Argument(s): sock - socket identifier.
#
# Returns:     Throws an exception if an error occurs.
#
########################################################################################
proc ixChariot::CollectPGStats {sock} \
{
    variable rxPortList

    variable enableMetrics
    variable pgWatchList

    if {$enableMetrics} {
        foreach txPort $rxPortList {
            scan $txPort "%d %d %d" chassisId cardId portId

            if [packetGroupStats get $chassisId $cardId $portId 0 128] {
                return -code error "Error getting packetGroupStats for $chassisId $cardId $portId"
            }
            for {set pgid 1} {$pgid < [packetGroupStats cget -numGroups]} {incr pgid} {
                if [packetGroupStats getGroup $pgid] {
                    return -code error "Error getting packetGroupStats for group $pgid, $chassisId $cardId $portId"
                }
                    
                set statString "<$chassisId,$cardId,$portId,$pgid"
                foreach pgStat $pgWatchList {
                    catch {lappend statString "$pgStat,[packetGroupStats cget -$pgStat]"}
                }
                lappend statString "end>"

                if [catch {puts $sock $statString} retMsg] {
                    return -code error "Error writing stats socket: $retMsg"
                }
                #LogEvent $statString
            }
        }
    }

    return $::TCL_OK

} ;# ixChariot::CollectPGStats
