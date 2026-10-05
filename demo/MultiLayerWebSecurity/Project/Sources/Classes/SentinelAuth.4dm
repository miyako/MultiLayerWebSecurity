

property _failCounts : Object
property _pendingPassphrases : Object
property _genCounts : Object

shared singleton Class constructor()
	This:C1470._failCounts:=New shared object:C1526
	
	This:C1470._pendingPassphrases:=New shared object:C1526
	This:C1470._genCounts:=New shared object:C1526
	
	
	
shared Function handleLogin($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	
	If (Session:C1714.hasPrivilege("sentinelAdmin"))
		return This:C1470._ok($resp; "Already authenticated")
	End if 
	
	var $body : Object
	$body:=JSON Parse:C1218($req.getText())
	var $ip : Text
	$ip:=cs:C1710.DoSGuard.me._extractIP($req)
	
	If ($body=Null:C1517)
		return This:C1470._fail($resp; $ip; 400; "Invalid JSON")
	End if 
	
	var $supplied : Text
	$supplied:=String:C10($body.passphrase)
	If ($supplied="")
		return This:C1470._fail($resp; $ip; 400; "Missing passphrase")
	End if 
	
	var $setAsDefault : Boolean
	$setAsDefault:=False:C215
	If (OB Is defined:C1231($body; "setAsDefault"))
		$setAsDefault:=Bool:C1537($body.setAsDefault)
	End if 
	
	If (cs:C1710.IPManager.me.isBlocked($ip))
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[AUTH] Login blocked — IP "+$ip+" is in blocklist"; \
			Information message:K38:1)
		return This:C1470._fail($resp; $ip; 403; "Forbidden")
	End if 
	
	var $windowMs : Integer
	$windowMs:=900000
	var $fails : Integer
	$fails:=0
	If (OB Is defined:C1231(This:C1470._failCounts; $ip))
		var $rec : Object
		$rec:=This:C1470._failCounts[$ip]
		If ((Milliseconds:C459-Num:C11($rec.firstMs))<$windowMs)
			$fails:=Num:C11($rec.count)
		End if 
	End if 
	
	var $maxFails : Integer
	$maxFails:=5
	If ($fails>=$maxFails)
		
		If (cs:C1710.DoSGuard.me._isMasterOn())
			cs:C1710.IPManager.me.blockIP($ip; 300; "Auth brute-force: "+String:C10($fails)+" failures")
			cs:C1710.AlertManager.me.raise("CRITICAL"; "AUTH"; "Brute-force login blocked"; \
				"IP "+$ip+" exceeded "+String:C10($maxFails)+" failed login attempts"; \
				New object:C1471("ip"; $ip; "failures"; $fails))
			LOG EVENT:C667(Into system standard outputs:K38:9; \
				"[AUTH] Brute-force lockout — IP "+$ip+" ("+String:C10($fails)+" failures)"; \
				Information message:K38:1)
			This:C1470._maybeDestructDynamic("lockout")
			return This:C1470._fail($resp; $ip; 403; "Forbidden")
		End if 
	End if 
	
	var $verified : Boolean
	$verified:=False:C215
	var $authVia : Text
	$authVia:=""
	
	var $hash : Text
	$hash:=Lowercase:C14(Generate digest:C1147($supplied; SHA256 digest:K66:4))
	If (OB Is defined:C1231(This:C1470._pendingPassphrases; $hash))
		var $pending : Object
		$pending:=This:C1470._pendingPassphrases[$hash]
		var $nowMs : Integer
		$nowMs:=Milliseconds:C459
		If (($pending#Null:C1517) & (Num:C11($pending.expiresAt)>$nowMs))
			var $bcrypt : Text
			$bcrypt:=Generate password hash:C1533($supplied)
			var $daysDpg : Real
			$daysDpg:=Num:C11(Current date:C33-!1970-01-01!)
			var $nowSecDpg : Real
			$nowSecDpg:=($daysDpg*86400)+Num:C11(Current time:C178)
			cs:C1710.ConfigManager.me.set("auth.dynamicPassphraseHash"; $bcrypt)
			cs:C1710.ConfigManager.me.set("auth.dynamicPassphraseCreatedAt"; $nowSecDpg)
			cs:C1710.ConfigManager.me.set("auth.dynamicPassphrasePersistent"; $setAsDefault)
			Use (This:C1470._pendingPassphrases)
				OB REMOVE:C1226(This:C1470._pendingPassphrases; $hash)
			End use 
			$verified:=True:C214
			$authVia:="pending-pool"
			LOG EVENT:C667(Into system standard outputs:K38:9; \
				"[AUTH-DPG] Committed (persistent: "+String:C10($setAsDefault)+") — IP "+$ip; \
				Information message:K38:1)
		End if 
	End if 
	
	If (Not:C34($verified))
		var $dpgStored : Text
		$dpgStored:=String:C10(cs:C1710.ConfigManager.me.get("auth.dynamicPassphraseHash"))
		If ($dpgStored#"") & (Length:C16($dpgStored)>3) & (Substring:C12($dpgStored; 1; 2)="$2")
			If (Verify password hash:C1534($supplied; $dpgStored))
				$verified:=True:C214
				$authVia:="active-dpg"
				LOG EVENT:C667(Into system standard outputs:K38:9; \
					"[AUTH-DPG] Login success — used active DPG — IP "+$ip; \
					Information message:K38:1)
			End if 
		End if 
	End if 
	
	If (Not:C34($verified))
		var $stored : Text
		$stored:=String:C10(cs:C1710.ConfigManager.me.get("auth.dashboardPassphrase"))
		If ($stored="")
			LOG EVENT:C667(Into system standard outputs:K38:9; \
				"[AUTH] Login denied — no passphrase configured"; \
				Error message:K38:3)
			return This:C1470._fail($resp; $ip; 403; "Forbidden")
		End if 
		If (Length:C16($stored)>3) & (Substring:C12($stored; 1; 2)="$2")
			$verified:=Verify password hash:C1534($supplied; $stored)
		Else 
			$verified:=($supplied=$stored)
			If ($verified)
				var $hashed : Text
				$hashed:=Generate password hash:C1533($supplied)
				cs:C1710.ConfigManager.me.set("auth.dashboardPassphrase"; $hashed)
				LOG EVENT:C667(Into system standard outputs:K38:9; \
					"[AUTH] Plaintext passphrase auto-hashed and saved"; \
					Information message:K38:1)
			End if 
		End if 
		If ($verified)
			$authVia:="static"
		End if 
	End if 
	
	If ($verified)
		Session:C1714.setPrivileges(New object:C1471("privilege"; "sentinelAdmin"))
		var $authDays : Real
		$authDays:=Num:C11(Current date:C33-!1970-01-01!)
		var $authNow : Real
		$authNow:=($authDays*86400)+Num:C11(Current time:C178)
		Use (Session:C1714.storage)
			Session:C1714.storage.auth:=New shared object:C1526("expiresAt"; $authNow+3600)
		End use 
		This:C1470._clearFails($ip)
		cs:C1710.RequestLogger.me.log("ADMIN"; $ip; "POST"; "/admin/auth/login"; 200; "Login success via "+$authVia)
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[AUTH] Login success — IP "+$ip+", via "+$authVia+", sentinelAdmin granted"; \
			Information message:K38:1)
		return This:C1470._ok($resp; "Authenticated")
	Else 
		This:C1470._recordFail($ip)
		cs:C1710.RequestLogger.me.log("BLOCKED"; $ip; "POST"; "/admin/auth/login"; 401; \
			"Login failure "+String:C10($fails+1)+"/"+String:C10($maxFails))
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[AUTH] Login failure from "+$ip+" ("+String:C10($fails+1)+"/"+\
			String:C10($maxFails)+")"; \
			Information message:K38:1)
		return This:C1470._fail($resp; $ip; 403; "Forbidden")
	End if 
	
	
	
	
shared Function handleLogout($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	
	var $ip : Text
	$ip:=cs:C1710.DoSGuard.me._extractIP($req)
	
	This:C1470._maybeDestructDynamic("logout")
	
	Session:C1714.clearPrivileges()
	Use (Session:C1714.storage)
		Session:C1714.storage.auth:=Null:C1517
	End use 
	
	cs:C1710.RequestLogger.me.log("ADMIN"; $ip; "POST"; "/admin/auth/logout"; 200; "Logout")
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[AUTH] Logout — IP "+$ip; \
		Information message:K38:1)
	
	return This:C1470._ok($resp; "Logged out")
	
	
	
shared Function handleAuthStatus($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	
	var $authenticated : Boolean
	$authenticated:=False:C215
	
	If (OB Is defined:C1231(Session:C1714.storage; "auth") & (Session:C1714.storage.auth#Null:C1517))
		var $statusDays : Real
		$statusDays:=Num:C11(Current date:C33-!1970-01-01!)
		var $statusNow : Real
		$statusNow:=($statusDays*86400)+Num:C11(Current time:C178)
		If (Num:C11(Session:C1714.storage.auth.expiresAt)>$statusNow)
			$authenticated:=True:C214
		End if 
	End if 
	If (Not:C34($authenticated))
		$authenticated:=Session:C1714.hasPrivilege("sentinelAdmin")
	End if 
	
	var $body : Object
	$body:=New object:C1471(\
		"authenticated"; $authenticated; \
		"privilege"; Choose:C955($authenticated; "sentinelAdmin"; "guest"))
	
	$resp.setBody(JSON Stringify:C1217($body))
	$resp.setHeader("Content-Type"; "application/json")
	$resp.setHeader("Cache-Control"; "no-store")
	$resp.setStatus(200)
	return $resp
	
	
	
	
Function _ok($resp : 4D:C1709.OutgoingMessage; $msg : Text) : 4D:C1709.OutgoingMessage
	$resp.setBody(JSON Stringify:C1217(New object:C1471("success"; True:C214; "message"; $msg)))
	$resp.setHeader("Content-Type"; "application/json")
	$resp.setHeader("Cache-Control"; "no-store")
	$resp.setStatus(200)
	return $resp
	
	
Function _fail($resp : 4D:C1709.OutgoingMessage; $ip : Text; $code : Integer; $msg : Text) : 4D:C1709.OutgoingMessage
	$resp.setBody(JSON Stringify:C1217(New object:C1471("success"; False:C215; "message"; $msg)))
	$resp.setHeader("Content-Type"; "application/json")
	$resp.setHeader("Cache-Control"; "no-store")
	$resp.setStatus($code)
	return $resp
	
	
Function _recordFail($ip : Text)
	
	var $windowMs : Integer
	$windowMs:=900000
	var $now : Integer
	$now:=Milliseconds:C459
	Use (This:C1470._failCounts)
		var $existing : Object
		If (OB Is defined:C1231(This:C1470._failCounts; $ip))
			$existing:=This:C1470._failCounts[$ip]
		End if 
		var $count : Integer
		var $firstMs : Integer
		If (($existing#Null:C1517) & (($now-Num:C11($existing.firstMs))<$windowMs))
			$count:=Num:C11($existing.count)+1
			$firstMs:=Num:C11($existing.firstMs)
		Else 
			$count:=1
			$firstMs:=$now
		End if 
		This:C1470._failCounts[$ip]:=New shared object:C1526(\
			"count"; $count; \
			"firstMs"; $firstMs)
	End use 
	
	
Function _clearFails($ip : Text)
	If (OB Is defined:C1231(This:C1470._failCounts; $ip))
		Use (This:C1470._failCounts)
			OB REMOVE:C1226(This:C1470._failCounts; $ip)
		End use 
	End if 
	
	
	
	
shared Function handleGeneratePassphrase($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	
	var $ip : Text
	$ip:=cs:C1710.DoSGuard.me._extractIP($req)
	
	If (cs:C1710.IPManager.me.isBlocked($ip))
		$resp.setBody(JSON Stringify:C1217(New object:C1471("success"; False:C215; "message"; "Forbidden")))
		$resp.setHeader("Content-Type"; "application/json")
		$resp.setHeader("Cache-Control"; "no-store")
		$resp.setStatus(403)
		return $resp
	End if 
	
	var $maxPerMin : Integer
	$maxPerMin:=10
	var $now : Integer
	$now:=Milliseconds:C459
	var $genCount : Integer
	$genCount:=0
	If (OB Is defined:C1231(This:C1470._genCounts; $ip))
		var $genRec : Object
		$genRec:=This:C1470._genCounts[$ip]
		If (($genRec#Null:C1517) & (($now-Num:C11($genRec.firstMs))<60000))
			$genCount:=Num:C11($genRec.count)
		End if 
	End if 
	If ($genCount>=$maxPerMin)
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[AUTH-DPG] Rate limit hit — IP "+$ip+" ("+String:C10($genCount)+"/min)"; \
			Information message:K38:1)
		$resp.setBody(JSON Stringify:C1217(New object:C1471(\
			"success"; False:C215; \
			"message"; "Too many generations — wait a minute"; \
			"retryAfterSec"; 60)))
		$resp.setHeader("Content-Type"; "application/json")
		$resp.setHeader("Cache-Control"; "no-store")
		$resp.setHeader("Retry-After"; "60")
		$resp.setStatus(429)
		return $resp
	End if 
	
	Use (This:C1470._genCounts)
		var $existingGen : Object
		If (OB Is defined:C1231(This:C1470._genCounts; $ip))
			$existingGen:=This:C1470._genCounts[$ip]
		End if 
		var $newCount : Integer
		var $firstMs : Integer
		If (($existingGen#Null:C1517) & (($now-Num:C11($existingGen.firstMs))<60000))
			$newCount:=Num:C11($existingGen.count)+1
			$firstMs:=Num:C11($existingGen.firstMs)
		Else 
			$newCount:=1
			$firstMs:=$now
		End if 
		This:C1470._genCounts[$ip]:=New shared object:C1526(\
			"count"; $newCount; \
			"firstMs"; $firstMs)
	End use 
	
	var $code : Text
	$code:=This:C1470._generateCode()
	var $hash : Text
	$hash:=Lowercase:C14(Generate digest:C1147($code; SHA256 digest:K66:4))
	
	Use (This:C1470._pendingPassphrases)
		var $keys : Collection
		$keys:=OB Keys:C1719(This:C1470._pendingPassphrases)
		var $k : Integer
		For ($k; 0; $keys.length-1)
			var $existingEntry : Object
			$existingEntry:=This:C1470._pendingPassphrases[$keys[$k]]
			If (($existingEntry#Null:C1517) & (String:C10($existingEntry.generatedBy)=$ip))
				OB REMOVE:C1226(This:C1470._pendingPassphrases; $keys[$k])
			End if 
		End for 
		
		var $keysAfter : Collection
		$keysAfter:=OB Keys:C1719(This:C1470._pendingPassphrases)
		var $k2 : Integer
		For ($k2; 0; $keysAfter.length-1)
			var $sweepEntry : Object
			$sweepEntry:=This:C1470._pendingPassphrases[$keysAfter[$k2]]
			If (($sweepEntry#Null:C1517) & (Num:C11($sweepEntry.expiresAt)<=$now))
				OB REMOVE:C1226(This:C1470._pendingPassphrases; $keysAfter[$k2])
			End if 
		End for 
		This:C1470._pendingPassphrases[$hash]:=New shared object:C1526(\
			"expiresAt"; $now+300000; \
			"generatedBy"; $ip; \
			"generatedAt"; $now)
	End use 
	
	cs:C1710.RequestLogger.me.log("AUTH-DPG"; $ip; "POST"; "/admin/auth/generate-passphrase"; 200; \
		"Generated 8-char DPG (TTL 300s)")
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[AUTH-DPG] Generated for IP "+$ip+" (TTL 300s)"; \
		Information message:K38:1)
	
	$resp.setBody(JSON Stringify:C1217(New object:C1471(\
		"success"; True:C214; \
		"passphrase"; $code; \
		"expiresInSec"; 300)))
	$resp.setHeader("Content-Type"; "application/json")
	$resp.setHeader("Cache-Control"; "no-store")
	$resp.setStatus(200)
	return $resp
	
	
	
	
shared Function handleClearDynamic($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	
	var $ip : Text
	$ip:=cs:C1710.DoSGuard.me._extractIP($req)
	
	var $authOk : Boolean
	$authOk:=False:C215
	If (OB Is defined:C1231(Session:C1714.storage; "auth") & (Session:C1714.storage.auth#Null:C1517))
		var $days : Real
		$days:=Num:C11(Current date:C33-!1970-01-01!)
		var $nowSec : Real
		$nowSec:=($days*86400)+Num:C11(Current time:C178)
		If (Num:C11(Session:C1714.storage.auth.expiresAt)>$nowSec)
			$authOk:=True:C214
		End if 
	End if 
	If (Not:C34($authOk))
		$authOk:=Session:C1714.hasPrivilege("sentinelAdmin")
	End if 
	If (Not:C34($authOk))
		return This:C1470._fail($resp; $ip; 401; "Authentication required")
	End if 
	
	This:C1470._destructDynamic()
	cs:C1710.RequestLogger.me.log("ADMIN"; $ip; "POST"; "/admin/auth/clear-dynamic"; 200; "Dynamic passphrase cleared")
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[AUTH-DPG] Cleared by admin — IP "+$ip; \
		Information message:K38:1)
	
	return This:C1470._ok($resp; "Dynamic passphrase cleared")
	
	
	
Function _generateCode() : Text
	
	var $alphabet : Text
	$alphabet:="23456789ABCDEFGHJKMNPQRSTUVWXYZ"
	var $alphaLen : Integer
	$alphaLen:=Length:C16($alphabet)
	var $seed : Text
	$seed:=Generate UUID:C1066+":"+String:C10(Milliseconds:C459)+":"+String:C10(Random:C100)+":"+Generate UUID:C1066
	var $hex : Text
	$hex:=Generate digest:C1147($seed; SHA256 digest:K66:4)
	var $code : Text
	$code:=""
	var $i : Integer
	For ($i; 1; 8)
		var $byteHex : Text
		$byteHex:=Substring:C12($hex; (($i-1)*2)+1; 2)
		var $hi : Integer
		var $lo : Integer
		$hi:=Position:C15(Lowercase:C14(Substring:C12($byteHex; 1; 1)); "0123456789abcdef")-1
		$lo:=Position:C15(Lowercase:C14(Substring:C12($byteHex; 2; 1)); "0123456789abcdef")-1
		If ($hi<0)
			$hi:=0
		End if 
		If ($lo<0)
			$lo:=0
		End if 
		var $idx : Integer
		$idx:=(($hi*16)+$lo)%$alphaLen
		$code:=$code+Substring:C12($alphabet; $idx+1; 1)
	End for 
	return $code
	
Function _maybeDestructDynamic($reason : Text)
	var $cfg : cs:C1710.ConfigManager
	$cfg:=cs:C1710.ConfigManager.me
	var $hash : Text
	$hash:=String:C10($cfg.get("auth.dynamicPassphraseHash"))
	If ($hash="")
		return 
	End if 
	var $persistent : Boolean
	$persistent:=Bool:C1537($cfg.get("auth.dynamicPassphrasePersistent"))
	If ($persistent)
		return 
	End if 
	This:C1470._destructDynamic()
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[AUTH-DPG] Destructed on "+$reason; \
		Information message:K38:1)
	
Function _destructDynamic()
	
	var $cfg : cs:C1710.ConfigManager
	$cfg:=cs:C1710.ConfigManager.me
	$cfg.set("auth.dynamicPassphraseHash"; Null:C1517)
	$cfg.set("auth.dynamicPassphraseCreatedAt"; Null:C1517)
	$cfg.set("auth.dynamicPassphrasePersistent"; False:C215)