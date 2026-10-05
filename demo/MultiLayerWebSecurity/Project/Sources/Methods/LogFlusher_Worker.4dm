//%attributes = {}


var $orch : cs:C1710.ProcessOrchestrator
$orch:=cs:C1710.ProcessOrchestrator.me
var $logger : cs:C1710.RequestLogger
$logger:=cs:C1710.RequestLogger.me
var $config : cs:C1710.ConfigManager
$config:=cs:C1710.ConfigManager.me

var $flushInterval : Real
$flushInterval:=Num:C11($config.get("logging.flushIntervalSeconds"))
If ($flushInterval<=0)
	$flushInterval:=2
End if 

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[LOG_FLUSHER] Online — flushing every "+String:C10($flushInterval; "###0.0")+"s"; \
Information message:K38:1)

While (Not:C34($orch.shouldShutdown()))
	
	
	$logger.flushToDisk()
	$orch.heartbeat("log_flusher")
	
	If ($orch.sleep($flushInterval))
		$logger.flushToDisk()
		break
	End if 
End while 

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[LOG_FLUSHER] Offline — final flush completed"; \
Information message:K38:1)