//%attributes = {}
var $orch : cs:C1710.ProcessOrchestrator
$orch:=cs:C1710.ProcessOrchestrator.me
var $honeypot : cs:C1710.Honeypot
$honeypot:=cs:C1710.Honeypot.me
var $config : cs:C1710.ConfigManager
$config:=cs:C1710.ConfigManager.me


var $intervalSec : Real
$intervalSec:=60

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[HONEYPOT_SWEEPER] Online — sweeping every "+String:C10($intervalSec; "###0")+"s"; \
Information message:K38:1)

While (Not:C34($orch.shouldShutdown()))
	
	$honeypot.sweep()
	
	$orch.heartbeat("honeypot_sweeper")
	
	If ($orch.sleep($intervalSec))
		break
	End if 
	
End while 

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[HONEYPOT_SWEEPER] Offline — clean shutdown"; \
Information message:K38:1)
