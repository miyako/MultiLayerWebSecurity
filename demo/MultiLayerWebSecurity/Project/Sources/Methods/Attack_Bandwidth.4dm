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
"[ATTACK][BANDWIDTH] Starting — pre: total="+String:C10($before.totalRequests)+\
" blocked="+String:C10($before.blockedRequests); \
Information message:K38:1)



var $normalPaths : Collection
$normalPaths:=New collection:C1472(\
"/api/public/users"; "/api/public/data"; "/api/public/search"; \
"/api/public/export"; "/api/public/import"; "/api/public/assets"; \
"/public"; "/health")

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][BANDWIDTH] Pass 1 — 200 normal requests across "+\
String:C10($normalPaths.length)+" endpoints"; \
Information message:K38:1)

For ($i; 1; 200)
	var $path : Text
	$path:=String:C10($normalPaths[$i%$normalPaths.length])
	$opts:=New object:C1471("method"; "GET"; "timeout"; 5)
	$http:=4D:C1709.HTTPRequest.new($base+$path+"?seq="+String:C10($i); $opts)
	$http.wait()
	If ($i%20=0)
		DELAY PROCESS:C323(Current process:C322; 1)
	End if 
End for 


var $reconPaths : Collection
$reconPaths:=New collection:C1472(\
"/wp-admin/"; "/wp-login.php"; "/.env"; "/.git/config"; \
"/phpmyadmin/"; "/phpinfo.php"; "/admin.php"; "/xmlrpc.php"; \
"/actuator/health"; "/server-status"; "/config.php"; \
"/.aws/credentials"; "/.ssh/id_rsa"; "/backup.sql")


var $fakeIPs : Collection
$fakeIPs:=New collection:C1472(\
"192.168.100.10"; "192.168.100.11"; "192.168.100.12"; \
"10.0.0.5"; "10.0.0.6"; "10.0.0.7"; "172.16.0.99")

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][BANDWIDTH] Pass 2 — "+String:C10($reconPaths.length*3)+\
" recon probes with IP rotation"; \
Information message:K38:1)

For ($i; 1; $reconPaths.length*3)
	var $fakeIP : Text
	$fakeIP:=String:C10($fakeIPs[$i%$fakeIPs.length])
	var $headers : Object
	$headers:=New object:C1471("X-Forwarded-For"; $fakeIP+", 127.0.0.1")
	$opts:=New object:C1471("method"; "GET"; "timeout"; 5; "headers"; $headers)
	$http:=4D:C1709.HTTPRequest.new($base+String:C10($reconPaths[$i%$reconPaths.length]); $opts)
	$http.wait()
End for 


var $traversal : Collection
$traversal:=New collection:C1472(\
"/api/%252e%252e/etc/passwd"; \
"/api/%2e%2e/%2e%2e/secret"; \
"/public/..%2f..%2fconfig"; \
"/api/v1/..%5c..%5cwin.ini"; \
"/api/..%c0%af..%c0%af/etc"; \
"/upload/..%2fSettings%2fdosguard_config.json")

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][BANDWIDTH] Pass 3 — "+String:C10($traversal.length*4)+\
" traversal attempts"; \
Information message:K38:1)

For ($i; 1; $traversal.length*4)
	$opts:=New object:C1471("method"; "GET"; "timeout"; 5)
	$http:=4D:C1709.HTTPRequest.new($base+String:C10($traversal[$i%$traversal.length]); $opts)
	$http.wait()
End for 

var $oversizePaths : Collection
$oversizePaths:=New collection:C1472(\
"/api/public/import"; "/api/public/export"; "/upload/test")

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][BANDWIDTH] Pass 4 — oversized body claims"; \
Information message:K38:1)

For ($i; 1; 30)
	var $bigCL : Integer
	$bigCL:=(15+(($i%5)*5))*1048576
	var $bigHeaders : Object
	$bigHeaders:=New object:C1471(\
		"Content-Type"; "application/json"; \
		"Content-Length"; String:C10($bigCL))
	$opts:=New object:C1471("method"; "POST"; "timeout"; 5; "headers"; $bigHeaders)
	$http:=4D:C1709.HTTPRequest.new(\
		$base+String:C10($oversizePaths[$i%$oversizePaths.length]); $opts)
	$http.wait()
End for 



var $badTypes : Collection
$badTypes:=New collection:C1472(\
"application/x-php"; \
"application/x-msdownload"; \
"text/html"; \
"application/octet-stream; boundary=exploit"; \
"multipart/form-data; filename=shell.php")

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][BANDWIDTH] Pass 5 — malformed content-type POST requests"; \
Information message:K38:1)

For ($i; 1; $badTypes.length*3)
	var $ctHeaders : Object
	$ctHeaders:=New object:C1471("Content-Type"; String:C10($badTypes[$i%$badTypes.length]))
	$opts:=New object:C1471("method"; "POST"; "timeout"; 5; "headers"; $ctHeaders)
	$http:=4D:C1709.HTTPRequest.new($base+"/upload/malware.php"; $opts)
	$http.wait()
End for 


var $badAgents : Collection
$badAgents:=New collection:C1472(\
""; \
"sqlmap/1.7"; \
"Nikto/2.1.6"; \
"Mozilla/5.0 zgrab/0.x"; \
"python-requests/2.28"; \
"masscan/1.3")

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][BANDWIDTH] Pass 6 — suspicious user agents"; \
Information message:K38:1)

For ($i; 1; $badAgents.length*5)
	var $agentHeader : Object
	var $agentStr : Text
	$agentStr:=String:C10($badAgents[$i%$badAgents.length])
	If ($agentStr="")
		$agentHeader:=New object:C1471
	Else 
		$agentHeader:=New object:C1471("User-Agent"; $agentStr)
	End if 
	$opts:=New object:C1471("method"; "GET"; "timeout"; 5; "headers"; $agentHeader)
	$http:=4D:C1709.HTTPRequest.new($base+"/api/public/data"; $opts)
	$http.wait()
End for 



var $after : Object
$after:=cs:C1710.DoSGuard.me.getPublicStats()

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[ATTACK][BANDWIDTH] Completed. Delta — allowed="+\
String:C10($after.allowedRequests-$before.allowedRequests)+\
" blocked="+String:C10($after.blockedRequests-$before.blockedRequests)+\
" rateLimited="+String:C10($after.rateLimitedRequests-$before.rateLimitedRequests)+\
" wafRejections="+String:C10($after.wafRejections-$before.wafRejections); \
Information message:K38:1)

Use (cs:C1710.Sentinel.me)
	cs:C1710.Sentinel.me._attackRunning:=False:C215
End use 
