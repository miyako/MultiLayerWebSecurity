//%attributes = {}


var $orch : cs:C1710.ProcessOrchestrator
$orch:=cs:C1710.ProcessOrchestrator.me
var $sonar : cs:C1710.Sonar
$sonar:=cs:C1710.Sonar.me


var $dataFolder : 4D:C1709.Folder
$dataFolder:=Folder:C1567(fk data folder:K87:12)
If (Not:C34($dataFolder.exists))
	$dataFolder.create()
End if 
var $archiveFile : 4D:C1709.File
$archiveFile:=File:C1566($dataFolder.path+"sonar_archive.jsonl")
If (Not:C34($archiveFile.exists))
	$archiveFile.setText(""; "UTF-8")
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[SONAR_DRONE] Initialized empty archive at "+$archiveFile.path; \
		Information message:K38:1)
End if 

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[SONAR_DRONE] Online — recon archive worker ready"; \
Information message:K38:1)

While (Not:C34($orch.shouldShutdown()))
	
	var $item : Object
	$item:=$sonar.dequeueDrone()
	
	If ($item#Null:C1517)
		var $payload : Text
		$payload:=JSON Stringify:C1217($item)
		var $sig : Text
		$sig:=Substring:C12(Generate digest:C1147($sonar._sigKey+":"+$payload; 2); 1; 16)
		
		var $archiveRecord : Object
		$archiveRecord:=New object:C1471(\
			"ts"; Timestamp:C1445; \
			"event"; "DRONE_ARCHIVE"; \
			"sig"; $sig; \
			"ip"; String:C10($item.ip); \
			"score"; Num:C11($item.score); \
			"type"; String:C10($item.type); \
			"fingerprint"; String:C10($item.fingerprint); \
			"url"; String:C10($item.url); \
			"ua"; String:C10($item.ua))
		
		var $existing : Text
		If ($archiveFile.exists)
			$existing:=$archiveFile.getText("UTF-8")
		End if 
		$archiveFile.setText($existing+JSON Stringify:C1217($archiveRecord)+Char:C90(10); "UTF-8")
		
		Use ($sonar._stats)
			$sonar._stats.droneArchived:=$sonar._stats.droneArchived+1
		End use 
	End if 
	
	$orch.heartbeat("sonar_drone")
	
	If ($orch.sleep(0.5))
		break
	End if 
	
End while 

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[SONAR_DRONE] Offline"; \
Information message:K38:1)
