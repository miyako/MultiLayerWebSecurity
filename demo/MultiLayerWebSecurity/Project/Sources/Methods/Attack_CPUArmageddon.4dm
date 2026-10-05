//%attributes = {}


var $port : Integer
$port:=WEB Server:C1674.HTTPPort
var $base : Text
$base:="http://127.0.0.1:"+String:C10($port)

var $opts : Object
var $http : 4D:C1709.HTTPRequest
var $i : Integer

var $before : Object
$before:=cs:C1710.DoSGuard.me.getPublicStats()

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][CPU_ARMAGEDDON] Starting — pre: allowed="+\
String:C10($before.allowedRequests)+" blocked="+\
String:C10($before.blockedRequests); \
Information message:K38:1)



LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][CPU_ARMAGEDDON] Pass 1 — 200 requests → /heavy"; \
Information message:K38:1)

For ($i; 1; 200)
	$opts:=New object:C1471("method"; "GET"; "timeout"; 10)
	$http:=4D:C1709.HTTPRequest.new($base+"/heavy?attack=dos&seq="+String:C10($i); $opts)
	$http.wait()
	If ($i%10=0)
		DELAY PROCESS:C323(Current process:C322; 1)
	End if 
End for 



var $mixedTargets : Collection
$mixedTargets:=New collection:C1472(\
"/heavy"; \
"/api/public/data"; \
"/health"; \
"/heavy"; \
"/api/public/search"; \
"/heavy"; \
"/public")

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][CPU_ARMAGEDDON] Pass 2 — 140 mixed-target requests"; \
Information message:K38:1)

For ($i; 1; 140)
	$opts:=New object:C1471("method"; "GET"; "timeout"; 10)
	$http:=4D:C1709.HTTPRequest.new(\
		$base+String:C10($mixedTargets[$i%$mixedTargets.length])+"?seq="+String:C10($i); \
		$opts)
	$http.wait()
	If ($i%15=0)
		DELAY PROCESS:C323(Current process:C322; 1)
	End if 
End for 



LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][CPU_ARMAGEDDON] Pass 3 — 25-request burst (no pacing)"; \
Information message:K38:1)

For ($i; 1; 25)
	$opts:=New object:C1471("method"; "GET"; "timeout"; 5)
	$http:=4D:C1709.HTTPRequest.new($base+"/heavy?burst=1&seq="+String:C10($i); $opts)
	$http.wait()
End for 


var $after : Object
$after:=cs:C1710.DoSGuard.me.getPublicStats()

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][CPU_ARMAGEDDON] Completed. Delta — "+\
"allowed="+String:C10($after.allowedRequests-$before.allowedRequests)+\
" blocked="+String:C10($after.blockedRequests-$before.blockedRequests)+\
" rateLimited="+String:C10($after.rateLimitedRequests-$before.rateLimitedRequests)+\
" panicRejections="+String:C10($after.panicRejections-$before.panicRejections)+\
" wafRejections="+String:C10($after.wafRejections-$before.wafRejections); \
Information message:K38:1)


Use (cs:C1710.Sentinel.me)
	cs:C1710.Sentinel.me._attackRunning:=False:C215
End use 
