//%attributes = {"executedOnServer":true}


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
"[ATTACK][HEADER_OVERFLOW] Starting"; \
Information message:K38:1)



LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][HEADER_OVERFLOW] Pass 1 — aggregate block overflow (40 × 220-byte headers)"; \
Information message:K38:1)

For ($i; 1; 20)
	var $bloatHeaders : Object
	$bloatHeaders:=New object:C1471
	var $j : Integer
	For ($j; 1; 40)
		
		var $padVal : Text
		var $k : Integer
		$padVal:=""
		For ($k; 1; 200)
			$padVal:=$padVal+"A"
		End for 
		$bloatHeaders["X-Padding-"+String:C10($j)]:=$padVal
	End for 
	$opts:=New object:C1471("method"; "GET"; "timeout"; 5; "headers"; $bloatHeaders)
	$http:=4D:C1709.HTTPRequest.new($base+"/api/public/data"; $opts)
	$http.wait()
End for 



LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][HEADER_OVERFLOW] Pass 2 — null byte injection probe"; \
Information message:K38:1)

For ($i; 1; 10)
	var $nullHeaders : Object
	$nullHeaders:=New object:C1471(\
		"X-Injection"; "value"+Char:C90(0)+"injected"; \
		"User-Agent"; "HeaderOverflowTest/1.0")
	$opts:=New object:C1471("method"; "GET"; "timeout"; 5; "headers"; $nullHeaders)
	$http:=4D:C1709.HTTPRequest.new($base+"/health"; $opts)
	$http.wait()
End for 



LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][HEADER_OVERFLOW] Pass 3 — single line overflow (4500-char value)"; \
Information message:K38:1)

For ($i; 1; 20)
	var $bigLineHeaders : Object
	var $bigVal : Text
	var $m : Integer
	$bigVal:=""
	For ($m; 1; 4500)
		$bigVal:=$bigVal+"B"
	End for 
	$bigLineHeaders:=New object:C1471(\
		"X-BigValue"; $bigVal; \
		"User-Agent"; "HeaderOverflowTest/1.0")
	$opts:=New object:C1471("method"; "GET"; "timeout"; 5; "headers"; $bigLineHeaders)
	$http:=4D:C1709.HTTPRequest.new($base+"/api/public/data"; $opts)
	$http.wait()
End for 



LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][HEADER_OVERFLOW] Pass 4 — CRLF injection in header value"; \
Information message:K38:1)

For ($i; 1; 15)
	var $crlfHeaders : Object
	$crlfHeaders:=New object:C1471(\
		"X-Inject"; "legitimate"+Char:C90(13)+Char:C90(10)+"X-Fake-Header: injected"; \
		"User-Agent"; "HeaderOverflowTest/1.0")
	$opts:=New object:C1471("method"; "GET"; "timeout"; 5; "headers"; $crlfHeaders)
	$http:=4D:C1709.HTTPRequest.new($base+"/api/public/data"; $opts)
	$http.wait()
End for 



LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][HEADER_OVERFLOW] Pass 5 — clean requests (regression guard)"; \
Information message:K38:1)

var $cleanBefore : Object
$cleanBefore:=cs:C1710.DoSGuard.me.getPublicStats()

For ($i; 1; 20)
	var $cleanHeaders : Object
	$cleanHeaders:=New object:C1471(\
		"User-Agent"; "Mozilla/5.0 (regression test)"; \
		"Accept"; "application/json")
	$opts:=New object:C1471("method"; "GET"; "timeout"; 5; "headers"; $cleanHeaders)
	$http:=4D:C1709.HTTPRequest.new($base+"/health"; $opts)
	$http.wait()
End for 

var $cleanAfter : Object
$cleanAfter:=cs:C1710.DoSGuard.me.getPublicStats()
var $cleanAllowed : Integer
$cleanAllowed:=$cleanAfter.allowedRequests-$cleanBefore.allowedRequests


var $after : Object
$after:=cs:C1710.DoSGuard.me.getPublicStats()

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][HEADER_OVERFLOW] Completed. Delta — "+\
"blocked="+String:C10($after.blockedRequests-$before.blockedRequests)+\
" invalid="+String:C10($after.invalidRequests-$before.invalidRequests)+\
" cleanPassed="+String:C10($cleanAllowed)+\
" (expect: blocked≥50, cleanPassed≈20)"; \
Information message:K38:1)

Use (cs:C1710.Sentinel.me)
	cs:C1710.Sentinel.me._attackRunning:=False:C215
End use 
