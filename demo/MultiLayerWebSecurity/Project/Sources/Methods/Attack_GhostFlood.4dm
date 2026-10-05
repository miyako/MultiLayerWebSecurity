//%attributes = {}


var $port : Integer
$port:=WEB Server:C1674.HTTPPort
var $base : Text
$base:="http://127.0.0.1:"+String:C10($port)

var $opts : Object
var $http : 4D:C1709.HTTPRequest
var $i : Integer


var $trusted : Collection
$trusted:=cs:C1710.ConfigManager.me.get("security.trustedProxies")
var $spoofingEnabled : Boolean
$spoofingEnabled:=False:C215
If ($trusted#Null:C1517)
	var $t : Integer
	For ($t; 0; $trusted.length-1)
		If (String:C10($trusted[$t])="127.0.0.1")
			$spoofingEnabled:=True:C214
		End if 
	End for 
End if 

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][GHOST_FLOOD] Starting — IP spoofing: "+\
Choose:C955($spoofingEnabled; "ACTIVE (127.0.0.1 in trustedProxies)"; \
"INACTIVE — single-IP mode (add 127.0.0.1 to security.trustedProxies to enable)"); \
Information message:K38:1)

var $before : Object
$before:=cs:C1710.DoSGuard.me.getPublicStats()


var $ghostPool : Collection
$ghostPool:=New collection:C1472
var $g : Integer
For ($g; 0; 49)
	var $subnet : Integer
	$subnet:=($g%5)+1
	$ghostPool.push("10.100."+String:C10($subnet)+"."+String:C10(($g%10)+1))
End for 

var $floodPaths : Collection
$floodPaths:=New collection:C1472(\
"/api/public/data"; "/api/public/search"; "/api/public/users"; \
"/health"; "/public"; "/api/public/export")



LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][GHOST_FLOOD] Pass 1 — 200 requests spread across 50 ghost IPs (4 req/IP)"; \
Information message:K38:1)

For ($i; 1; 200)
	var $ghostIP : Text
	$ghostIP:=String:C10($ghostPool[$i%$ghostPool.length])
	var $ghostHeaders : Object
	$ghostHeaders:=New object:C1471(\
		"X-Forwarded-For"; $ghostIP+", 127.0.0.1"; \
		"User-Agent"; "Mozilla/5.0 (GhostClient/"+String:C10($i)+")")
	$opts:=New object:C1471("method"; "GET"; "timeout"; 5; "headers"; $ghostHeaders)
	$http:=4D:C1709.HTTPRequest.new(\
		$base+String:C10($floodPaths[$i%$floodPaths.length])+"?ghost="+String:C10($i); \
		$opts)
	$http.wait()
	If ($i%25=0)
		DELAY PROCESS:C323(Current process:C322; 1)
	End if 
End for 



LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][GHOST_FLOOD] Pass 2 — 500 high-rate requests (no pacing) targeting global cap"; \
Information message:K38:1)

For ($i; 1; 500)
	$ghostIP:=String:C10($ghostPool[$i%$ghostPool.length])
	$ghostHeaders:=New object:C1471(\
		"X-Forwarded-For"; $ghostIP+", 127.0.0.1"; \
		"User-Agent"; "FloodBot/2.0")
	$opts:=New object:C1471("method"; "GET"; "timeout"; 3; "headers"; $ghostHeaders)
	$http:=4D:C1709.HTTPRequest.new(\
		$base+String:C10($floodPaths[$i%$floodPaths.length]); \
		$opts)
	$http.wait()
End for 



var $honeypotTargets : Collection
$honeypotTargets:=New collection:C1472(\
"/.env"; "/wp-login.php"; "/admin.php"; "/.git/config"; "/backup.sql")

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][GHOST_FLOOD] Pass 3 — "+String:C10($honeypotTargets.length*4)+\
" honeypot probes from ghost IPs"; \
Information message:K38:1)

For ($i; 1; $honeypotTargets.length*4)
	$ghostIP:=String:C10($ghostPool[($i*7)%$ghostPool.length])
	$ghostHeaders:=New object:C1471(\
		"X-Forwarded-For"; $ghostIP+", 127.0.0.1"; \
		"User-Agent"; "Mozilla/5.0")
	$opts:=New object:C1471("method"; "GET"; "timeout"; 5; "headers"; $ghostHeaders)
	$http:=4D:C1709.HTTPRequest.new(\
		$base+String:C10($honeypotTargets[$i%$honeypotTargets.length]); \
		$opts)
	$http.wait()
End for 


var $after : Object
$after:=cs:C1710.DoSGuard.me.getPublicStats()

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][GHOST_FLOOD] Completed. Delta — "+\
"total="+String:C10($after.totalRequests-$before.totalRequests)+\
" allowed="+String:C10($after.allowedRequests-$before.allowedRequests)+\
" blocked="+String:C10($after.blockedRequests-$before.blockedRequests)+\
" globalRateHits="+String:C10($after.globalRateHits-$before.globalRateHits)+\
" honeypotHits="+String:C10($after.honeypotHits-$before.honeypotHits)+\
" panicRejections="+String:C10($after.panicRejections-$before.panicRejections); \
Information message:K38:1)

Use (cs:C1710.Sentinel.me)
	cs:C1710.Sentinel.me._attackRunning:=False:C215
End use 
