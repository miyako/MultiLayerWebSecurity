
property _path : Text
property blocklist : Object
property allowlist : Object
property strikes : Object

shared singleton Class constructor()
	This:C1470._path:=Folder:C1567(fk data folder:K87:12).path+"ip_lists.json"
	This:C1470.blocklist:=New shared object:C1526
	This:C1470.allowlist:=New shared object:C1526
	This:C1470.strikes:=New shared object:C1526
	This:C1470._load()
	
	
shared Function blockIP($ip : Text; $durationSeconds : Integer; $reason : Text) : Object
	var $result : Object
	$result:=New object:C1471("success"; True:C214; "message"; "")
	
	If (This:C1470.isAllowlisted($ip))
		$result.success:=False:C215
		$result.message:="Cannot block allowlisted IP: "+$ip
		return $result
	End if 
	
	var $permThreshold : Integer
	$permThreshold:=Num:C11(cs:C1710.ConfigManager.me.get("rateLimiting.permanentBlockStrikes"))
	If ($permThreshold<=0)
		$permThreshold:=5
	End if 
	
	
	var $currentStrikes : Integer
	Use (This:C1470)
		If (Not:C34(OB Is defined:C1231(This:C1470.strikes; $ip)))
			This:C1470.strikes[$ip]:=0
		End if 
		This:C1470.strikes[$ip]:=This:C1470.strikes[$ip]+1
		$currentStrikes:=This:C1470.strikes[$ip]
		
		var $blockEntryTemp : Object
		$blockEntryTemp:=New object:C1471("addedAt"; Timestamp:C1445; "reason"; $reason; "strikes"; $currentStrikes)
		
		If ($currentStrikes>=$permThreshold)
			$blockEntryTemp.permanent:=True:C214
			$blockEntryTemp.expiry:=0
			This:C1470._promoteToPermament($ip)
			$result.message:="IP "+$ip+" permanently blocked (strike "+String:C10($currentStrikes)+")"
		Else 
			$blockEntryTemp.permanent:=False:C215
			var $dur : Integer
			$dur:=$durationSeconds
			If ($dur<=0)
				$dur:=300
			End if 
			$blockEntryTemp.expiry:=Milliseconds:C459+($dur*1000)
			$blockEntryTemp.durationSeconds:=$dur
			$result.message:="IP "+$ip+" blocked for "+String:C10($dur)+"s (strike "+String:C10($currentStrikes)+"/"+String:C10($permThreshold)+")"
		End if 
		
		This:C1470.blocklist[$ip]:=OB Copy:C1225($blockEntryTemp; ck shared:K85:29; This:C1470)
	End use 
	
	This:C1470._save()
	return $result
	
Function _promoteToPermament($ip : Text) : Object
	var $entry : Object
	$entry:=Null:C1517
	
	Use (This:C1470.blocklist)
		$entry:=This:C1470.blocklist[$ip]
		If ($entry#Null:C1517)
			$entry.permanent:=True:C214
			$entry.expiry:=0
			This:C1470.blocklist[$ip]:=$entry
		End if 
	End use 
	
	This:C1470._save()
	return $entry
	
shared Function unblockIP($ip : Text) : Boolean
	If (OB Is defined:C1231(This:C1470.blocklist; $ip))
		Use (This:C1470.blocklist)
			OB REMOVE:C1226(This:C1470.blocklist; $ip)
		End use 
		This:C1470._save()
		return True:C214
	End if 
	return False:C215
	
shared Function isBlocked($ip : Text) : Boolean
	If (This:C1470.isAllowlisted($ip))
		return False:C215
	End if 
	
	If (Not:C34(OB Is defined:C1231(This:C1470.blocklist; $ip)))
		return False:C215
	End if 
	
	var $e : Object
	$e:=This:C1470.blocklist[$ip]
	
	If ($e.permanent)
		return True:C214
	End if 
	
	If (Milliseconds:C459<$e.expiry)
		return True:C214
	End if 
	
	Use (This:C1470.blocklist)
		OB REMOVE:C1226(This:C1470.blocklist; $ip)
	End use 
	This:C1470._save()
	return False:C215
	
shared Function getBlocklist() : Collection
	var $result : Collection
	$result:=New collection:C1472
	var $keys : Collection
	$keys:=OB Keys:C1719(This:C1470.blocklist)
	var $i : Integer
	
	For ($i; 0; $keys.length-1)
		var $e : Object
		$e:=OB Copy:C1225(This:C1470.blocklist[$keys[$i]])
		$e.ip:=$keys[$i]
		If ($e.permanent)
			$e.timeRemaining:="Permanent"
			$e.status:="permanent"
		Else 
			var $remMs : Integer
			$remMs:=$e.expiry-Milliseconds:C459
			If ($remMs>0)
				var $remSec : Integer
				$remSec:=$remMs\1000
				If ($remSec>3600)
					$e.timeRemaining:=String:C10($remSec\3600)+"h "+String:C10(($remSec%3600)\60)+"m"
				Else 
					If ($remSec>60)
						$e.timeRemaining:=String:C10($remSec\60)+"m "+String:C10($remSec%60)+"s"
					Else 
						$e.timeRemaining:=String:C10($remSec)+"s"
					End if 
				End if 
				$e.status:="active"
			Else 
				$e.timeRemaining:="Expired"
				$e.status:="expired"
			End if 
		End if 
		$result.push($e)
	End for 
	
	return $result
	
shared Function clearBlocklist()
	Use (This:C1470)
		This:C1470.blocklist:=New shared object:C1526
	End use 
	This:C1470._save()
	
shared Function clearExpired() : Integer
	var $keys : Collection
	$keys:=OB Keys:C1719(This:C1470.blocklist)
	var $removed : Integer
	$removed:=0
	var $i : Integer
	
	Use (This:C1470.blocklist)
		For ($i; 0; $keys.length-1)
			If (Not:C34(This:C1470.blocklist[$keys[$i]].permanent))
				If (Milliseconds:C459>=This:C1470.blocklist[$keys[$i]].expiry)
					OB REMOVE:C1226(This:C1470.blocklist; $keys[$i])
					$removed:=$removed+1
				End if 
			End if 
		End for 
	End use 
	
	If ($removed>0)
		This:C1470._save()
	End if 
	return $removed
	
shared Function allowIP($ip : Text; $reason : Text) : Object
	var $result : Object
	$result:=New object:C1471("success"; True:C214; "message"; "IP "+$ip+" allowlisted")
	
	Use (This:C1470.allowlist)
		This:C1470.allowlist[$ip]:=OB Copy:C1225(New object:C1471("reason"; $reason; "addedAt"; Timestamp:C1445); ck shared:K85:29; This:C1470.allowlist)
	End use 
	
	If (OB Is defined:C1231(This:C1470.blocklist; $ip))
		Use (This:C1470.blocklist)
			OB REMOVE:C1226(This:C1470.blocklist; $ip)
		End use 
		$result.message:=$result.message+" (removed from blocklist)"
	End if 
	
	This:C1470._save()
	return $result
	
shared Function removeFromAllowlist($ip : Text) : Boolean
	If (OB Is defined:C1231(This:C1470.allowlist; $ip))
		Use (This:C1470.allowlist)
			OB REMOVE:C1226(This:C1470.allowlist; $ip)
		End use 
		This:C1470._save()
		return True:C214
	End if 
	return False:C215
	
shared Function isAllowlisted($ip : Text) : Boolean
	If (OB Is defined:C1231(This:C1470.allowlist; $ip))
		return True:C214
	End if 
	return False:C215
	
shared Function getAllowlist() : Collection
	var $result : Collection
	$result:=New collection:C1472
	var $keys : Collection
	$keys:=OB Keys:C1719(This:C1470.allowlist)
	var $i : Integer
	For ($i; 0; $keys.length-1)
		var $e : Object
		$e:=OB Copy:C1225(This:C1470.allowlist[$keys[$i]])
		$e.ip:=$keys[$i]
		$result.push($e)
	End for 
	return $result
	
shared Function clearAllowlist()
	Use (This:C1470)
		This:C1470.allowlist:=New shared object:C1526
	End use 
	This:C1470._save()
	
shared Function getStrikes($ip : Text) : Integer
	If (OB Is defined:C1231(This:C1470.strikes; $ip))
		return This:C1470.strikes[$ip]
	End if 
	return 0
	
shared Function resetStrikes($ip : Text)
	If (OB Is defined:C1231(This:C1470.strikes; $ip))
		Use (This:C1470.strikes)
			OB REMOVE:C1226(This:C1470.strikes; $ip)
		End use 
		This:C1470._save()
	End if 
	
shared Function clearAllStrikes()
	Use (This:C1470)
		This:C1470.strikes:=New shared object:C1526
	End use 
	This:C1470._save()
	
shared Function clearAll() : Object
	
	Use (This:C1470)
		This:C1470.blocklist:=New shared object:C1526
		This:C1470.allowlist:=New shared object:C1526
		This:C1470.strikes:=New shared object:C1526
	End use 
	
	var $saved : Boolean
	$saved:=This:C1470._save()
	
	If (Not:C34($saved))
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[IPMANAGER] clearAll: in-memory wiped but DISK SAVE FAILED — ip_lists.json may still hold stale entries"; \
			Error message:K38:3)
		return New object:C1471(\
			"success"; False:C215; \
			"message"; "In-memory lists cleared but disk save FAILED — ip_lists.json may still hold stale data. Check server logs."; \
			"blockedCount"; 0; \
			"allowedCount"; 0; \
			"strikeCount"; 0)
	End if 
	
	return New object:C1471(\
		"success"; True:C214; \
		"message"; "blocklist, allowlist, and strikes cleared"; \
		"blockedCount"; 0; \
		"allowedCount"; 0; \
		"strikeCount"; 0)
	
shared Function getStatus() : Object
	var $s : Object
	$s:=New object:C1471("blockedCount"; OB Keys:C1719(This:C1470.blocklist).length; \
		"allowedCount"; OB Keys:C1719(This:C1470.allowlist).length; \
		"permanentBlocks"; 0; \
		"totalStrikes"; 0)
	
	var $bKeys : Collection
	$bKeys:=OB Keys:C1719(This:C1470.blocklist)
	var $k : Integer
	For ($k; 0; $bKeys.length-1)
		If (This:C1470.blocklist[$bKeys[$k]].permanent)
			$s.permanentBlocks:=$s.permanentBlocks+1
		End if 
	End for 
	
	var $sKeys : Collection
	$sKeys:=OB Keys:C1719(This:C1470.strikes)
	For ($k; 0; $sKeys.length-1)
		$s.totalStrikes:=$s.totalStrikes+This:C1470.strikes[$sKeys[$k]]
	End for 
	
	return $s
	
Function _load()
	var $file : 4D:C1709.File
	$file:=File:C1566(This:C1470._path)
	If ($file.exists)
		var $data : Object
		$data:=JSON Parse:C1218($file.getText("UTF-8"))
		If ($data#Null:C1517)
			Use (This:C1470)
				
				If ($data.blocklist#Null:C1517)
					This:C1470.blocklist:=OB Copy:C1225($data.blocklist; ck shared:K85:29; This:C1470)
				Else 
					This:C1470.blocklist:=New shared object:C1526
				End if 
				
				If ($data.allowlist#Null:C1517)
					This:C1470.allowlist:=OB Copy:C1225($data.allowlist; ck shared:K85:29; This:C1470)
				Else 
					This:C1470.allowlist:=New shared object:C1526
				End if 
				
				If ($data.strikes#Null:C1517)
					This:C1470.strikes:=OB Copy:C1225($data.strikes; ck shared:K85:29; This:C1470)
				Else 
					This:C1470.strikes:=New shared object:C1526
				End if 
				
			End use 
		End if 
	End if 
	
Function _save() : Boolean
	
	var $orch : cs:C1710.ProcessOrchestrator
	$orch:=cs:C1710.ProcessOrchestrator.me
	
	If (Not:C34($orch.acquire("sentinel.ip.persist"; 5)))
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[IPMANAGER] _save: FAILED — timeout acquiring sentinel.ip.persist (5s) — disk write skipped, in-memory state may diverge from ip_lists.json"; \
			Error message:K38:3)
		return False:C215
	End if 
	
	var $folder : 4D:C1709.Folder
	$folder:=File:C1566(This:C1470._path).parent
	If (Not:C34($folder.exists))
		$folder.create()
	End if 
	
	
	var $data : Object
	$data:=New object:C1471(\
		"blocklist"; OB Copy:C1225(This:C1470.blocklist); \
		"allowlist"; OB Copy:C1225(This:C1470.allowlist); \
		"strikes"; OB Copy:C1225(This:C1470.strikes))
	
	var $payload : Text
	$payload:=JSON Stringify:C1217($data; *)
	
	var $finalFile : 4D:C1709.File
	$finalFile:=File:C1566(This:C1470._path)
	var $tmpFile : 4D:C1709.File
	$tmpFile:=File:C1566(This:C1470._path+".tmp")
	
	$tmpFile.setText($payload; "UTF-8")
	If ($finalFile.exists)
		$finalFile.delete()
	End if 
	$tmpFile.rename($finalFile.fullName)
	
	$orch.release("sentinel.ip.persist")
	
	If (Not:C34(File:C1566(This:C1470._path).exists))
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[IPMANAGER] _save: FAILED — post-rename verification missed ip_lists.json"; \
			Error message:K38:3)
		return False:C215
	End if 
	
	return True:C214