
property _logFolder : Text
property _maxEntries : Integer
property _idCounter : Integer
property entries : Collection
property hourlyStats : Collection
property _currentHour : Text
property _hourAccum : Object
property topIPs : Object
property _writeBuffer : Collection
property _writeBufferSoftCap : Integer
property _topIPsCap : Integer

shared singleton Class constructor()
	This:C1470._logFolder:=Folder:C1567(fk data folder:K87:12).path+"Logs/"
	This:C1470._maxEntries:=2000
	This:C1470._idCounter:=0
	
	This:C1470.entries:=New shared collection:C1527
	This:C1470.hourlyStats:=New shared collection:C1527
	This:C1470._currentHour:=""
	This:C1470._hourAccum:=New shared object:C1526(\
		"allowed"; 0; "blocked"; 0; "rateLimited"; 0; "invalid"; 0; \
		"uploads"; 0; "waf"; 0)
	This:C1470.topIPs:=New shared object:C1526
	
	This:C1470._writeBuffer:=New shared collection:C1527
	This:C1470._writeBufferSoftCap:=5000
	
	This:C1470._topIPsCap:=5000
	
	var $folder : 4D:C1709.Folder
	$folder:=Folder:C1567(This:C1470._logFolder)
	If (Not:C34($folder.exists))
		$folder.create()
	End if 
	
	
shared Function log($type : Text; $ip : Text; $verb : Text; $url : Text; \
$status : Integer; $detail : Text; $body : Text; $clientType : Text)
	
	If ($clientType="")
		Try
			If (OB Is defined:C1231(Session:C1714.storage; "authData") && (Session:C1714.storage.authData#Null:C1517))
				$clientType:=String:C10(Session:C1714.storage.authData.clientType)
			End if 
		Catch
			$clientType:=""
		End try
	End if 
	
	This:C1470._idCounter:=This:C1470._idCounter+1
	
	var $entryTemp : Object
	$entryTemp:=New object:C1471("id"; This:C1470._idCounter; \
		"timestamp"; String:C10(Current date:C33; ISO date:K1:8)+"T"+String:C10(Current time:C178; HH MM SS:K7:1); \
		"eventType"; $type; \
		"ip"; $ip; \
		"verb"; $verb; \
		"url"; $url; \
		"statusCode"; $status; \
		"detail"; $detail; \
		"clientType"; $clientType)
	
	
	var $shouldCaptureBody : Boolean
	$shouldCaptureBody:=False:C215
	Case of 
		: ($type="BLOCKED")
			$shouldCaptureBody:=True:C214
		: ($type="BLOCKED_UPLOAD")
			$shouldCaptureBody:=True:C214
		: ($type="RATE_LIMITED")
			$shouldCaptureBody:=True:C214
		: ($type="INVALID")
			$shouldCaptureBody:=True:C214
		: ($type="INVALID_UPLOAD")
			$shouldCaptureBody:=True:C214
		: ($type="OVERSIZED_UPLOAD")
			$shouldCaptureBody:=True:C214
		: ($type="MALFORMED_URL")
			$shouldCaptureBody:=True:C214
		: ($type="TRAVERSAL")
			$shouldCaptureBody:=True:C214
		: ($type="RECON_PROBE")
			$shouldCaptureBody:=True:C214
	End case 
	
	If ($shouldCaptureBody) && (Length:C16($body)>0)
		var $bodyCapped : Text
		$bodyCapped:=$body
		var $bodyTruncated : Boolean
		$bodyTruncated:=False:C215
		If (Length:C16($bodyCapped)>2048)
			$bodyCapped:=Substring:C12($bodyCapped; 1; 2048)
			$bodyTruncated:=True:C214
		End if 
		$entryTemp.body:=$bodyCapped
		$entryTemp.bodyTruncated:=$bodyTruncated
	End if 
	
	Use (This:C1470.entries)
		This:C1470.entries.push(OB Copy:C1225($entryTemp; ck shared:K85:29; This:C1470.entries))
		If (This:C1470.entries.length>This:C1470._maxEntries)
			This:C1470.entries.shift()
		End if 
	End use 
	
	This:C1470._aggregateHour($type)
	
	
	Use (This:C1470.topIPs)
		If (Not:C34(OB Is defined:C1231(This:C1470.topIPs; $ip)))
			If (OB Keys:C1719(This:C1470.topIPs).length>=This:C1470._topIPsCap)
				This:C1470._evictLowestTopIP()
			End if 
			This:C1470.topIPs[$ip]:=0
		End if 
		This:C1470.topIPs[$ip]:=This:C1470.topIPs[$ip]+1
	End use 
	
	
	var $diskEntry : Object
	$diskEntry:=OB Copy:C1225($entryTemp)
	If (OB Is defined:C1231($diskEntry; "body"))
		OB REMOVE:C1226($diskEntry; "body")
	End if 
	If (OB Is defined:C1231($diskEntry; "bodyTruncated"))
		OB REMOVE:C1226($diskEntry; "bodyTruncated")
	End if 
	var $line : Text
	$line:=JSON Stringify:C1217($diskEntry)+"\n"
	var $needsFlush : Boolean
	$needsFlush:=False:C215
	Use (This:C1470._writeBuffer)
		This:C1470._writeBuffer.push($line)
		If (This:C1470._writeBuffer.length>This:C1470._writeBufferSoftCap)
			$needsFlush:=True:C214
		End if 
	End use 
	If ($needsFlush)
		
		This:C1470.flushToDisk()
	End if 
	
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"["+$type+"] "+$ip+" "+$verb+" "+$url+" "+String:C10($status)+" "+$detail; \
		Information message:K38:1)
	
	
shared Function getRecent($count : Integer) : Collection
	var $n : Integer
	$n:=$count
	If ($n<=0)
		$n:=100
	End if 
	If (This:C1470.entries.length<=$n)
		return This:C1470.entries.copy()
	End if 
	return This:C1470.entries.slice(This:C1470.entries.length-$n)
	
	
shared Function search($filters : Object) : Collection
	var $results : Collection
	$results:=This:C1470.entries.copy()
	
	If ($filters#Null:C1517)
		If (OB Is defined:C1231($filters; "eventType"))
			If ($filters.eventType#"ALL")
				If ($filters.eventType#"")
					$results:=$results.filter(Formula:C1597($1.value.eventType=String:C10($2)); $filters.eventType)
				End if 
			End if 
		End if 
		If (OB Is defined:C1231($filters; "ip"))
			If ($filters.ip#"")
				$results:=$results.filter(Formula:C1597(Position:C15(String:C10($2); $1.value.ip)>0); $filters.ip)
			End if 
		End if 
		If (OB Is defined:C1231($filters; "url"))
			If ($filters.url#"")
				$results:=$results.filter(Formula:C1597(Position:C15(String:C10($2); $1.value.url)>0); $filters.url)
			End if 
		End if 
		If (OB Is defined:C1231($filters; "statusCode"))
			If ($filters.statusCode>0)
				$results:=$results.filter(Formula:C1597($1.value.statusCode=Num:C11($2)); $filters.statusCode)
			End if 
		End if 
	End if 
	
	return $results
	
	
shared Function getHourlyStats() : Collection
	var $stats : Collection
	$stats:=This:C1470.hourlyStats.copy()
	var $current : Object
	$current:=OB Copy:C1225(This:C1470._hourAccum)
	$current.hour:=This:C1470._currentHour
	$stats.push($current)
	return $stats
	
	
shared Function getTopIPs($count : Integer) : Collection
	var $n : Integer
	$n:=$count
	If ($n<=0)
		$n:=10
	End if 
	
	var $result : Collection
	$result:=New collection:C1472
	var $keys : Collection
	$keys:=OB Keys:C1719(This:C1470.topIPs)
	var $i : Integer
	For ($i; 0; $keys.length-1)
		$result.push(New object:C1471("ip"; $keys[$i]; "count"; This:C1470.topIPs[$keys[$i]]))
	End for 
	$result:=$result.orderBy("count desc")
	
	If ($result.length>$n)
		$result:=$result.slice(0; $n)
	End if 
	return $result
	
	
shared Function getStats() : Object
	return New object:C1471("totalLogged"; This:C1470._idCounter; \
		"inMemory"; This:C1470.entries.length; \
		"uniqueIPs"; OB Keys:C1719(This:C1470.topIPs).length; \
		"currentHour"; This:C1470._currentHour)
	
	
shared Function exportCSV() : Text
	var $csv : Text
	$csv:="ID,Timestamp,EventType,IP,Verb,URL,StatusCode,Detail\n"
	var $i : Integer
	For ($i; 0; This:C1470.entries.length-1)
		var $e : Object
		$e:=This:C1470.entries[$i]
		$csv:=$csv+String:C10($e.id)+","+\
			This:C1470._escapeCSV($e.timestamp)+","+\
			This:C1470._escapeCSV($e.eventType)+","+\
			This:C1470._escapeCSV($e.ip)+","+\
			This:C1470._escapeCSV($e.verb)+","+\
			This:C1470._escapeCSV($e.url)+","+\
			String:C10($e.statusCode)+","+\
			This:C1470._escapeCSV($e.detail)+"\n"
	End for 
	return $csv
	
	
	
Function _escapeCSV($field : Text) : Text
	var $clean : Text
	$clean:=Replace string:C233($field; Char:C90(13); " ")
	$clean:=Replace string:C233($clean; Char:C90(10); " ")
	return "\""+Replace string:C233($clean; "\""; "\"\"")+"\""
	
	
shared Function clear()
	
	This:C1470.flushToDisk()
	Use (This:C1470)
		This:C1470.entries:=New shared collection:C1527
		This:C1470.topIPs:=New shared object:C1526
		This:C1470._writeBuffer:=New shared collection:C1527
	End use 
	
	
Function _evictLowestTopIP()
	var $keys : Collection
	$keys:=OB Keys:C1719(This:C1470.topIPs)
	If ($keys.length=0)
		return 
	End if 
	var $minKey : Text
	$minKey:=String:C10($keys[0])
	var $minVal : Integer
	$minVal:=This:C1470.topIPs[$minKey]
	var $i : Integer
	For ($i; 1; $keys.length-1)
		var $k : Text
		$k:=String:C10($keys[$i])
		If (This:C1470.topIPs[$k]<$minVal)
			$minVal:=This:C1470.topIPs[$k]
			$minKey:=$k
		End if 
	End for 
	OB REMOVE:C1226(This:C1470.topIPs; $minKey)
	
	
Function _aggregateHour($type : Text)
	var $hour : Text
	$hour:=String:C10(Current date:C33; ISO date:K1:8)+"T"+Substring:C12(String:C10(Current time:C178; HH MM SS:K7:1); 1; 2)
	
	If ($hour#This:C1470._currentHour)
		If (This:C1470._currentHour#"")
			var $archivedTemp : Object
			$archivedTemp:=New object:C1471(\
				"hour"; This:C1470._currentHour; \
				"allowed"; This:C1470._hourAccum.allowed; \
				"blocked"; This:C1470._hourAccum.blocked; \
				"rateLimited"; This:C1470._hourAccum.rateLimited; \
				"invalid"; This:C1470._hourAccum.invalid; \
				"uploads"; This:C1470._hourAccum.uploads; \
				"waf"; This:C1470._hourAccum.waf)
			
			Use (This:C1470.hourlyStats)
				This:C1470.hourlyStats.push(OB Copy:C1225($archivedTemp; ck shared:K85:29; This:C1470.hourlyStats))
				If (This:C1470.hourlyStats.length>48)
					This:C1470.hourlyStats.shift()
				End if 
			End use 
		End if 
		This:C1470._currentHour:=$hour
		Use (This:C1470)
			This:C1470._hourAccum:=New shared object:C1526(\
				"allowed"; 0; "blocked"; 0; "rateLimited"; 0; "invalid"; 0; \
				"uploads"; 0; "waf"; 0)
		End use 
	End if 
	
	Use (This:C1470._hourAccum)
		Case of 
			: ($type="ALLOWED")
				This:C1470._hourAccum.allowed:=This:C1470._hourAccum.allowed+1
			: ($type="BLOCKED") | ($type="BLOCKED_UPLOAD")
				This:C1470._hourAccum.blocked:=This:C1470._hourAccum.blocked+1
			: ($type="RATE_LIMITED") | ($type="GLOBAL_RATE_LIMIT")
				This:C1470._hourAccum.rateLimited:=This:C1470._hourAccum.rateLimited+1
			: ($type="INVALID") | ($type="OVERSIZED_UPLOAD") | ($type="INVALID_UPLOAD")
				This:C1470._hourAccum.invalid:=This:C1470._hourAccum.invalid+1
			: ($type="UPLOAD_OK")
				This:C1470._hourAccum.uploads:=This:C1470._hourAccum.uploads+1
			: ($type="TRAVERSAL") | ($type="MALFORMED_URL") | ($type="RECON_PROBE")
				This:C1470._hourAccum.waf:=This:C1470._hourAccum.waf+1
		End case 
	End use 
	
	
shared Function flushToDisk()
	var $orch : cs:C1710.ProcessOrchestrator
	$orch:=cs:C1710.ProcessOrchestrator.me
	
	If (Not:C34($orch.acquire("sentinel.log.flush"; 1)))
		return 
	End if 
	
	
	var $batch : Collection
	$batch:=New collection:C1472
	Use (This:C1470._writeBuffer)
		If (This:C1470._writeBuffer.length=0)
			$orch.release("sentinel.log.flush")
			return 
		End if 
		$batch:=This:C1470._writeBuffer.copy()
		
		While (This:C1470._writeBuffer.length>0)
			This:C1470._writeBuffer.shift()
		End while 
	End use 
	
	var $blob : Text
	$blob:=""
	var $i : Integer
	For ($i; 0; $batch.length-1)
		$blob:=$blob+String:C10($batch[$i])
	End for 
	
	
	var $filePath : Text
	$filePath:=This:C1470._logFolder+"dos_"+Substring:C12(String:C10(Current date:C33; ISO date:K1:8); 1; 10)+".log"
	var $file : 4D:C1709.File
	$file:=File:C1566($filePath)
	If ($file.exists)
		$file.setText($file.getText("UTF-8")+$blob; "UTF-8")
	Else 
		$file.setText($blob; "UTF-8")
	End if 
	
	$orch.release("sentinel.log.flush")