

property _hits : Collection
property _hitCount : Integer

shared singleton Class constructor()
	This:C1470._hits:=New shared collection:C1527
	This:C1470._hitCount:=0
	
	
	
shared Function isHoneypotURL($url : Text) : Boolean
	If (Not:C34(Bool:C1537(cs:C1710.ConfigManager.me.get("defenses.honeypot"))))
		return False:C215
	End if 
	
	var $paths : Collection
	$paths:=cs:C1710.ConfigManager.me.get("honeypot.paths")
	If ($paths=Null:C1517)
		return False:C215
	End if 
	If ($paths.length=0)
		return False:C215
	End if 
	
	var $lowerURL : Text
	$lowerURL:=Lowercase:C14($url)
	
	var $i : Integer
	For ($i; 0; $paths.length-1)
		var $pattern : Text
		$pattern:=Lowercase:C14(String:C10($paths[$i]))
		If (Length:C16($pattern)>0)
			If (Position:C15($pattern; $lowerURL)>0)
				return True:C214
			End if 
		End if 
	End for 
	return False:C215
	
	
	
shared Function recordHit($ip : Text; $url : Text; $headersRaw : Text)
	
	If (Not:C34(cs:C1710.DoSGuard.me._isMasterOn()))
		return 
	End if 
	
	var $banDur : Integer
	$banDur:=Num:C11(cs:C1710.ConfigManager.me.get("honeypot.banDurationSec"))
	If ($banDur<=0)
		$banDur:=86400
	End if 
	
	var $severity : Text
	$severity:=String:C10(cs:C1710.ConfigManager.me.get("honeypot.alertSeverity"))
	If ($severity="")
		$severity:="CRITICAL"
	End if 
	
	
	cs:C1710.IPManager.me.blockIP($ip; $banDur; "Honeypot hit: "+$url)
	
	var $hitTemp : Object
	$hitTemp:=New object:C1471(\
		"ip"; $ip; \
		"url"; $url; \
		"timestamp"; String:C10(Current date:C33; ISO date:K1:8)+"T"+String:C10(Current time:C178; HH MM SS:K7:1); \
		"banDuration"; $banDur)
	
	Use (This:C1470._hits)
		This:C1470._hits.push(OB Copy:C1225($hitTemp; ck shared:K85:29; This:C1470._hits))
		If (This:C1470._hits.length>200)
			This:C1470._hits.shift()
		End if 
	End use 
	
	
	Use (This:C1470)
		This:C1470._hitCount:=This:C1470._hitCount+1
	End use 
	
	cs:C1710.AlertManager.me.raise($severity; "HONEYPOT"; "Honeypot triggered"; \
		"IP "+$ip+" hit "+$url+" — "+String:C10($banDur)+"s ban applied"; \
		New object:C1471("ip"; $ip; "url"; $url; "banDuration"; $banDur))
	
	
	cs:C1710.RequestLogger.me.log("BLOCKED"; $ip; "GET"; $url; 403; \
		"Honeypot — banned "+String:C10($banDur)+"s"; "")
	
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[HONEYPOT] Hit from "+$ip+" → "+$url+" (ban "+String:C10($banDur)+"s)"; \
		Information message:K38:1)
	
	
	
	
shared Function handleProbe($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	
	var $ip : Text
	$ip:=cs:C1710.DoSGuard.me._extractIP($req)
	
	
	If (Not:C34(cs:C1710.DoSGuard.me._isMasterOn()))
		$resp.setStatus(404)
		$resp.setHeader("Content-Type"; "text/plain")
		$resp.setHeader("Cache-Control"; "no-store")
		$resp.setBody("Not Found")
		return $resp
	End if 
	
	
	This:C1470.recordHit($ip; $req.url; "")
	
	$resp.setStatus(403)
	$resp.setHeader("Content-Type"; "text/plain")
	$resp.setHeader("Cache-Control"; "no-store")
	$resp.setBody("Forbidden")
	return $resp
	
	
	
shared Function sweep()
	cs:C1710.DoSGuard.me.sweepWindows()
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[HONEYPOT] Sweep — "+String:C10(This:C1470._hits.length)+" hits in memory, "+\
		String:C10(This:C1470._hitCount)+" lifetime"; \
		Information message:K38:1)
	
	
	
shared Function getHits($count : Integer) : Collection
	var $n : Integer
	$n:=$count
	If ($n<=0)
		$n:=50
	End if 
	If (This:C1470._hits.length<=$n)
		return This:C1470._hits.copy()
	End if 
	return This:C1470._hits.slice(This:C1470._hits.length-$n)
	
	
shared Function getStats() : Object
	return New object:C1471(\
		"totalHits"; This:C1470._hitCount; \
		"recentHits"; This:C1470._hits.length)
	
	
	
shared Function clear()
	Use (This:C1470)
		This:C1470._hits:=New shared collection:C1527
		This:C1470._hitCount:=0
	End use 
	