//%attributes = {}


var $orch : cs:C1710.ProcessOrchestrator
$orch:=cs:C1710.ProcessOrchestrator.me
var $sonar : cs:C1710.Sonar
$sonar:=cs:C1710.Sonar.me
var $ipMgr : cs:C1710.IPManager
$ipMgr:=cs:C1710.IPManager.me

var $dataFolder : 4D:C1709.Folder
$dataFolder:=Folder:C1567(fk data folder:K87:12)
If (Not:C34($dataFolder.exists))
	$dataFolder.create()
End if 
var $killFile : 4D:C1709.File
$killFile:=File:C1566($dataFolder.path+"sonar_kills.jsonl")
If (Not:C34($killFile.exists))
	$killFile.setText(""; "UTF-8")
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[SONAR_SNIPER] Initialized empty kill log at "+$killFile.path; \
		Information message:K38:1)
End if 

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[SONAR_SNIPER] Online — immediate kill worker ready"; \
Information message:K38:1)

While (Not:C34($orch.shouldShutdown()))
	
	var $item : Object
	$item:=$sonar.dequeueSniper()
	
	If ($item#Null:C1517)
		
		If ($ipMgr.isAllowlisted(String:C10($item.ip)))
			LOG EVENT:C667(Into system standard outputs:K38:9; \
				"[SONAR_SNIPER] Skipped allowlisted "+String:C10($item.ip)+\
				" — score "+String:C10(Num:C11($item.score))+\
				" — type "+String:C10($item.type); \
				Information message:K38:1)
		Else 
			
			If (Not:C34(cs:C1710.DoSGuard.me._isMasterOn()))
				LOG EVENT:C667(Into system standard outputs:K38:9; \
					"[SONAR_SNIPER] Skipped "+String:C10($item.ip)+\
					" — master OFF (no block applied)"; \
					Information message:K38:1)
			Else 
				var $reason : Text
				$reason:="Sonar Sniper: "+String:C10($item.type)+" score="+String:C10(Num:C11($item.score))
				$ipMgr.blockIP(String:C10($item.ip); 3600; $reason)
				
				Use ($sonar._stats)
					$sonar._stats.sniperKills:=$sonar._stats.sniperKills+1
				End use 
				
				var $killRecord : Object
				$killRecord:=New object:C1471(\
					"ts"; Timestamp:C1445; \
					"event"; "SNIPER_KILL"; \
					"ip"; String:C10($item.ip); \
					"score"; Num:C11($item.score); \
					"type"; String:C10($item.type); \
					"fingerprint"; String:C10($item.fingerprint); \
					"url"; String:C10($item.url); \
					"ua"; String:C10($item.ua))
				
				var $existing : Text
				If ($killFile.exists)
					$existing:=$killFile.getText("UTF-8")
				End if 
				$killFile.setText($existing+JSON Stringify:C1217($killRecord)+Char:C90(10); "UTF-8")
				
				LOG EVENT:C667(Into system standard outputs:K38:9; \
					"[SONAR_SNIPER] Killed "+String:C10($item.ip)+" — score "+String:C10(Num:C11($item.score)); \
					Information message:K38:1)
			End if 
		End if 
	End if 
	
	$orch.heartbeat("sonar_sniper")
	
	If ($orch.sleep(0.1))
		break
	End if 
	
End while 

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[SONAR_SNIPER] Offline"; \
Information message:K38:1)
