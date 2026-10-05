//%attributes = {}


var $orch : cs:C1710.ProcessOrchestrator
$orch:=cs:C1710.ProcessOrchestrator.me
var $guard : cs:C1710.DoSGuard
$guard:=cs:C1710.DoSGuard.me
var $config : cs:C1710.ConfigManager
$config:=cs:C1710.ConfigManager.me

var $intervalMs : Integer
$intervalMs:=Num:C11($config.get("monitoring.cpuSampleIntervalMs"))
If ($intervalMs<=0)
	$intervalMs:=2000
End if 
var $intervalSec : Real
$intervalSec:=$intervalMs/1000

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[CPU_MONITOR] Online — sampling every "+String:C10($intervalMs)+"ms"; \
Information message:K38:1)

While (Not:C34($orch.shouldShutdown()))
	
	var $activity : Object
	$activity:=Process activity:C1495(Processes only:K5:35)
	var $totalCPU : Real
	$totalCPU:=0
	var $webProcesses : Integer
	$webProcesses:=0
	var $preemptiveProcesses : Integer
	$preemptiveProcesses:=0
	var $cooperativeProcesses : Integer
	$cooperativeProcesses:=0
	var $heaviest : Object
	$heaviest:=New object:C1471("name"; ""; "cpuUsage"; 0)
	
	If ($activity#Null:C1517) & (OB Is defined:C1231($activity; "processes"))
		var $i : Integer
		For ($i; 0; $activity.processes.length-1)
			var $p : Object
			$p:=$activity.processes[$i]
			If (OB Is defined:C1231($p; "cpuUsage"))
				var $pct : Real
				$pct:=$p.cpuUsage*100
				$totalCPU:=$totalCPU+$pct
				
				If ($pct>$heaviest.cpuUsage)
					$heaviest:=New object:C1471("name"; String:C10($p.name); "cpuUsage"; $pct)
				End if 
				
				If (Bool:C1537($p.preemptive))
					$preemptiveProcesses:=$preemptiveProcesses+1
				Else 
					$cooperativeProcesses:=$cooperativeProcesses+1
				End if 
				
				If ($p.type=-8) | (Position:C15("Web"; String:C10($p.name))>0) | (Position:C15("HTTP"; String:C10($p.name))>0)
					$webProcesses:=$webProcesses+1
				End if 
			End if 
		End for 
	End if 
	
	$guard.updateCPUSample($totalCPU; $preemptiveProcesses+$cooperativeProcesses; \
		$webProcesses; $heaviest)
	
	
	$guard.checkCPURising($totalCPU)
	$guard.checkCPUPanicTrigger($totalCPU)
	
	$orch.heartbeat("cpu_monitor")
	
	If ($orch.sleep($intervalSec))
		break
	End if 
End while 

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[CPU_MONITOR] Offline — clean shutdown"; \
Information message:K38:1)