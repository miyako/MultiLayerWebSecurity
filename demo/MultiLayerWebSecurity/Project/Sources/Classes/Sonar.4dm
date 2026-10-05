
property _sniperQueue : Collection
property _droneQueue : Collection
property _stats : Object
property _sigKey : Text

shared singleton Class constructor()
	This:C1470._sniperQueue:=New shared collection:C1527
	This:C1470._droneQueue:=New shared collection:C1527
	This:C1470._stats:=New shared object:C1526
	Use (This:C1470._stats)
		This:C1470._stats.intercepted:=0
		This:C1470._stats.signaled:=0
		This:C1470._stats.sniperKills:=0
		This:C1470._stats.droneArchived:=0
		This:C1470._stats.droppedOverflow:=0
	End use 
	This:C1470._sigKey:=Generate UUID:C1066
	
	
	
shared Function intercept($ipClient : Text; $url : Text; $headersRaw : Text) : Object
	
	var $masterCfg : Variant
	$masterCfg:=cs:C1710.ConfigManager.me.get("defenses.master")
	If (($masterCfg#Null:C1517) & Not:C34(Bool:C1537($masterCfg)))
		Use (This:C1470._stats)
			This:C1470._stats.intercepted:=This:C1470._stats.intercepted+1
		End use 
		return New object:C1471("ip"; $ipClient; "score"; 0; \
			"fingerprint"; ""; "type"; "BYPASSED"; \
			"clientType"; ""; "clientFamily"; ""; "spoofed"; False:C215)
	End if 
	
	
	If ($ipClient#"") && (cs:C1710.IPManager.me.isAllowlisted($ipClient))
		Use (This:C1470._stats)
			This:C1470._stats.intercepted:=This:C1470._stats.intercepted+1
		End use 
		return New object:C1471("ip"; $ipClient; "score"; 0; \
			"fingerprint"; ""; "type"; "ALLOWLISTED"; \
			"clientType"; ""; "clientFamily"; ""; "spoofed"; False:C215)
	End if 
	
	var $ua : Text
	$ua:=This:C1470._extractUA($headersRaw)
	
	
	var $client : Object
	$client:=This:C1470.classifyClient($headersRaw)
	
	var $fingerprint : Text
	$fingerprint:=This:C1470._buildFingerprint($ipClient; $ua; $url)
	
	var $score : Integer
	$score:=This:C1470._scoreRequest($ipClient; $url; $ua)+Num:C11($client.score)
	If ($score>100)
		$score:=100
	End if 
	
	var $type : Text
	If ($score>=80)
		$type:="SNIPER_TARGET"
	Else 
		If ($score>=30)
			$type:="RECON_PROBE"
		Else 
			If ($score>0)
				$type:="LOW_SIGNAL"
			Else 
				$type:="CLEAN"
			End if 
		End if 
	End if 
	
	Use (This:C1470._stats)
		This:C1470._stats.intercepted:=This:C1470._stats.intercepted+1
	End use 
	
	If ($score>0)
		This:C1470.signal($ipClient; $url; $ua; $fingerprint; $type; $score)
	End if 
	
	return New object:C1471("ip"; $ipClient; "score"; $score; \
		"fingerprint"; $fingerprint; "type"; $type; \
		"clientType"; $client.type; "clientFamily"; $client.family; "spoofed"; $client.spoofed)
	
	
shared Function inspect($req : 4D:C1709.IncomingMessage) : Text
	
	If (Session:C1714.storage.authData=Null:C1517)
		return ""
	End if 
	return String:C10(Session:C1714.storage.authData.clientIP)
	
	
shared Function signal($ip : Text; $url : Text; $ua : Text; \
$fingerprint : Text; $type : Text; $score : Integer)
	
	If ($ip#"") && (cs:C1710.IPManager.me.isAllowlisted($ip))
		return 
	End if 
	
	var $item : Object
	$item:=New shared object:C1526
	Use ($item)
		$item.ip:=$ip
		$item.url:=$url
		$item.ua:=$ua
		$item.fingerprint:=$fingerprint
		$item.type:=$type
		$item.score:=$score
		$item.ts:=Timestamp:C1445
	End use 
	
	var $queued : Boolean
	$queued:=False:C215
	
	If ($score>=80)
		Use (This:C1470._sniperQueue)
			If (This:C1470._sniperQueue.length<500)
				This:C1470._sniperQueue.push($item)
				$queued:=True:C214
			End if 
		End use 
	Else 
		Use (This:C1470._droneQueue)
			If (This:C1470._droneQueue.length<2000)
				This:C1470._droneQueue.push($item)
				$queued:=True:C214
			End if 
		End use 
	End if 
	
	Use (This:C1470._stats)
		If ($queued)
			This:C1470._stats.signaled:=This:C1470._stats.signaled+1
		Else 
			This:C1470._stats.droppedOverflow:=This:C1470._stats.droppedOverflow+1
		End if 
	End use 
	
	
shared Function dequeueSniper() : Object
	
	var $item : Object
	$item:=Null:C1517
	Use (This:C1470._sniperQueue)
		If (This:C1470._sniperQueue.length>0)
			$item:=OB Copy:C1225(This:C1470._sniperQueue.shift())
		End if 
	End use 
	return $item
	
	
shared Function dequeueDrone() : Object
	
	var $item : Object
	$item:=Null:C1517
	Use (This:C1470._droneQueue)
		If (This:C1470._droneQueue.length>0)
			$item:=OB Copy:C1225(This:C1470._droneQueue.shift())
		End if 
	End use 
	return $item
	
	
shared Function getStats() : Object
	return OB Copy:C1225(This:C1470._stats)
	
	
shared Function getQueueSnapshot() : Collection
	var $result : Collection
	$result:=New collection:C1472
	var $i : Integer
	var $cap : Integer
	
	$cap:=This:C1470._sniperQueue.length
	If ($cap>25)
		$cap:=25
	End if 
	For ($i; 0; $cap-1)
		$result.push(OB Copy:C1225(This:C1470._sniperQueue[$i]))
	End for 
	
	var $remaining : Integer
	$remaining:=50-$result.length
	$cap:=This:C1470._droneQueue.length
	If ($cap>$remaining)
		$cap:=$remaining
	End if 
	For ($i; 0; $cap-1)
		$result.push(OB Copy:C1225(This:C1470._droneQueue[$i]))
	End for 
	
	return $result
	
	
Function _buildFingerprint($ip : Text; $ua : Text; $url : Text) : Text
	var $parts : Collection
	$parts:=Split string:C1554($ip; ".")
	var $ipPrefix : Text
	If ($parts.length>=3)
		$ipPrefix:=String:C10($parts[0])+"."+String:C10($parts[1])+"."+String:C10($parts[2])
	Else 
		$ipPrefix:=$ip
	End if 
	
	var $raw : Text
	$raw:=$ipPrefix+"|"+Substring:C12($ua; 1; 40)+"|"+Substring:C12($url; 1; 20)
	
	var $hash : Text
	$hash:=Generate digest:C1147($raw; 2)
	return Substring:C12($hash; 1; 12)
	
	
Function _extractUA($headersRaw : Text) : Text
	return This:C1470._extractHeader($headersRaw; "User-Agent")
	
	
Function _extractHeader($headersRaw : Text; $name : Text) : Text
	
	var $needle : Text
	$needle:=Lowercase:C14($name)+":"
	var $needleLen : Integer
	$needleLen:=Length:C16($needle)
	var $normalized : Text
	$normalized:=Replace string:C233($headersRaw; Char:C90(13); "")
	var $lines : Collection
	$lines:=Split string:C1554($normalized; Char:C90(10))
	var $i : Integer
	For ($i; 0; $lines.length-1)
		var $line : Text
		$line:=Trim:C1853(String:C10($lines[$i]))
		If (Position:C15($needle; Lowercase:C14($line))=1)
			return Trim:C1853(Substring:C12($line; $needleLen+1))
		End if 
	End for 
	return ""
	
	
shared Function classifyClient($headersRaw : Text) : Object
	
	var $ua : Text
	$ua:=This:C1470._extractUA($headersRaw)
	var $lc : Text
	$lc:=Lowercase:C14($ua)
	
	Case of 
		: (Position:C15("curl/"; $lc)>0)
			return New object:C1471("type"; "CURL"; "family"; "curl"; "spoofed"; False:C215; "score"; 25)
		: (Position:C15("postmanruntime"; $lc)>0)
			return New object:C1471("type"; "POSTMAN"; "family"; "Postman"; "spoofed"; False:C215; "score"; 25)
		: (Position:C15("wget"; $lc)>0)
			return New object:C1471("type"; "WGET"; "family"; "wget"; "spoofed"; False:C215; "score"; 25)
		: (Position:C15("python-requests"; $lc)>0)
			return New object:C1471("type"; "PYTHON"; "family"; "python-requests"; "spoofed"; False:C215; "score"; 25)
		: (Position:C15("go-http-client"; $lc)>0)
			return New object:C1471("type"; "GO_HTTP"; "family"; "Go"; "spoofed"; False:C215; "score"; 25)
		: (Position:C15("powershell"; $lc)>0) | (Position:C15("windowspowershell"; $lc)>0)
			return New object:C1471("type"; "POWERSHELL"; "family"; "PowerShell"; "spoofed"; False:C215; "score"; 25)
	End case 
	
	If (Position:C15("googlebot"; $lc)>0)
		return New object:C1471("type"; "BOT"; "family"; "Googlebot"; "spoofed"; False:C215; "score"; 50)
	End if 
	If (Position:C15("bingbot"; $lc)>0)
		return New object:C1471("type"; "BOT"; "family"; "Bingbot"; "spoofed"; False:C215; "score"; 50)
	End if 
	If (Position:C15("bot/"; $lc)>0) | (Position:C15("crawler"; $lc)>0) | (Position:C15("spider"; $lc)>0)
		return New object:C1471("type"; "BOT"; "family"; "Other"; "spoofed"; False:C215; "score"; 40)
	End if 
	
	If (Position:C15("mozilla"; $lc)>0)
		var $family : Text
		$family:="Browser"
		Case of 
			: (Position:C15("firefox/"; $lc)>0)
				$family:="Firefox"
			: (Position:C15("edg/"; $lc)>0)
				$family:="Edge"
			: (Position:C15("chrome/"; $lc)>0)
				$family:="Chrome"
			: (Position:C15("safari/"; $lc)>0)
				$family:="Safari"
		End case 
		
		var $hasFetch : Boolean
		$hasFetch:=(This:C1470._extractHeader($headersRaw; "Sec-Fetch-Dest")#"")\
			 | (This:C1470._extractHeader($headersRaw; "Sec-Fetch-Mode")#"")\
			 | (This:C1470._extractHeader($headersRaw; "Sec-Fetch-Site")#"")\
			 | (This:C1470._extractHeader($headersRaw; "Sec-Ch-Ua")#"")
		If ($hasFetch)
			return New object:C1471("type"; "BROWSER"; "family"; $family; "spoofed"; False:C215; "score"; 0)
		Else 
			return New object:C1471("type"; "SPOOFED_BROWSER"; "family"; $family; "spoofed"; True:C214; "score"; 60)
		End if 
	End if 
	
	If ($ua="")
		return New object:C1471("type"; "UNKNOWN"; "family"; "(no UA)"; "spoofed"; False:C215; "score"; 30)
	End if 
	
	return New object:C1471("type"; "SCRIPTED"; "family"; "Other"; "spoofed"; False:C215; "score"; 20)
	
	
Function _scoreRequest($ip : Text; $url : Text; $ua : Text) : Integer
	
	var $score : Integer
	$score:=0
	
	If ($ip#"")
		If (cs:C1710.IPManager.me.isBlocked($ip))
			$score:=$score+80
		End if 
	End if 
	
	var $urlLower : Text
	$urlLower:=Lowercase:C14($url)
	If (Position:C15("../"; $urlLower)>0)
		$score:=$score+50
	End if 
	If (Position:C15("eval("; $urlLower)>0)
		$score:=$score+50
	End if 
	If (Position:C15("<script"; $urlLower)>0)
		$score:=$score+50
	End if 
	If (Position:C15("union select"; $urlLower)>0)
		$score:=$score+50
	End if 
	
	If (Position:C15("'--"; $urlLower)>0) | (Position:C15("\";--"; $urlLower)>0)
		$score:=$score+50
	End if 
	
	
	If ($score>100)
		$score:=100
	End if 
	
	return $score