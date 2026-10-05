//%attributes = {}


var $orch : cs:C1710.ProcessOrchestrator
$orch:=cs:C1710.ProcessOrchestrator.me
var $guard : cs:C1710.DoSGuard
$guard:=cs:C1710.DoSGuard.me
var $config : cs:C1710.ConfigManager
$config:=cs:C1710.ConfigManager.me

var $intervalSec : Real
$intervalSec:=1

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[PANIC_WATCHDOG] Online"; \
Information message:K38:1)

var $alerts : cs:C1710.AlertManager
$alerts:=cs:C1710.AlertManager.me


While (Not:C34($orch.shouldShutdown()))
	
	var $cpu : Real
	$cpu:=$guard.getCPU()
	
	var $globalCount : Integer
	$globalCount:=$guard.getGlobalRateCount()
	
	var $globalCap : Integer
	$globalCap:=Num:C11($config.get("rateLimiting.globalMaxPerMinute"))
	If ($globalCap<=0)
		$globalCap:=10000
	End if 
	
	var $cpuHighThresh : Real
	$cpuHighThresh:=Num:C11($config.get("monitoring.cpuPanicTriggerAbove"))
	If ($cpuHighThresh<=0)
		$cpuHighThresh:=85
	End if 
	
	If (($globalCount>($globalCap*3)) && ($cpu>($cpuHighThresh-10)) && (Not:C34($guard.isPanicMode())))
		$alerts.raise("WARNING"; "COMPOUND_ATTACK"; \
			"Compound attack signal — traffic + CPU"; \
			"Traffic "+String:C10($globalCount)+"/"+String:C10($globalCap)+\
			" req/min, CPU "+String:C10($cpu; "###0.0")+"% — panic engages on confirmed sustained saturation"; \
			New object:C1471("globalCount"; $globalCount; "globalCap"; $globalCap; "cpu"; $cpu))
	End if 
	
	$orch.heartbeat("panic_watchdog")
	
	If ($orch.sleep($intervalSec))
		break
	End if 
End while 

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[PANIC_WATCHDOG] Offline"; \
Information message:K38:1)