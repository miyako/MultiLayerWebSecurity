

property _windows : Object
property _globalWindow : Collection
property stats : Object
property _minuteCount : Integer
property _minuteStart : Integer
property _rateHistory : Collection
property _cpuSample : Object
property _cpuPanicActive : Boolean
property _cpuPanicUntil : Integer
property _panicMode : Boolean
property _panicUntil : Integer
property _panicTriggeredAt : Integer
property _panicReason : Text
property _cpuRisingSince : Integer

shared singleton Class constructor()
	This:C1470._windows:=New shared object:C1526
	This:C1470._globalWindow:=New shared collection:C1527
	This:C1470.stats:=New shared object:C1526(\
		"totalRequests"; 0; \
		"allowedRequests"; 0; \
		"blockedRequests"; 0; \
		"rateLimitedRequests"; 0; \
		"invalidRequests"; 0; \
		"wafRejections"; 0; \
		"globalRateHits"; 0; \
		"panicRejections"; 0; \
		"honeypotHits"; 0; \
		"startTime"; Milliseconds:C459)
	This:C1470._minuteCount:=0
	This:C1470._minuteStart:=Milliseconds:C459
	This:C1470._rateHistory:=New shared collection:C1527
	
	This:C1470._cpuSample:=New shared object:C1526(\
		"cpuPercent"; 0; \
		"processCount"; 0; \
		"webProcessCount"; 0; \
		"sampleTime"; Milliseconds:C459; \
		"heaviestName"; ""; \
		"heaviestPct"; 0)
	This:C1470._cpuSample.history:=New shared collection:C1527
	
	This:C1470._cpuPanicActive:=False:C215
	This:C1470._cpuPanicUntil:=0
	This:C1470._panicMode:=False:C215
	This:C1470._panicUntil:=0
	This:C1470._panicTriggeredAt:=0
	This:C1470._panicReason:=""
	This:C1470._cpuRisingSince:=0
	
	
	
	
shared Function authenticateRequest($url : Text; $headersRaw : Text; $clientIP : Text) : Object
	
	
	Use (This:C1470.stats)
		This:C1470.stats.totalRequests:=This:C1470.stats.totalRequests+1
	End use 
	
	
	var $masterCfg : Variant
	$masterCfg:=cs:C1710.ConfigManager.me.get("defenses.master")
	var $masterOff : Boolean
	$masterOff:=($masterCfg#Null:C1517) & Not:C34(Bool:C1537($masterCfg))
	If ($masterOff)
		Use (This:C1470.stats)
			This:C1470.stats.allowedRequests:=This:C1470.stats.allowedRequests+1
		End use 
		return New object:C1471("accept"; True:C214; "status"; 200; \
			"reason"; "Master Off — defenses bypassed"; "retryAfterSec"; 0)
	End if 
	
	
	If (This:C1470._cpuPanicActive)
		var $panicIP : Text
		$panicIP:=This:C1470._extractIPFromHeader($headersRaw; $clientIP)
		
		If (cs:C1710.IPManager.me.isAllowlisted($panicIP))
			Use (This:C1470.stats)
				This:C1470.stats.allowedRequests:=This:C1470.stats.allowedRequests+1
			End use 
			return New object:C1471("accept"; True:C214; "status"; 200; "reason"; "Allowed"; "retryAfterSec"; 0)
		End if 
		
		Use (This:C1470.stats)
			This:C1470.stats.blockedRequests:=This:C1470.stats.blockedRequests+1
			This:C1470.stats.panicRejections:=This:C1470.stats.panicRejections+1
		End use 
		return New object:C1471("accept"; False:C215; "status"; 503; "reason"; "CPU Panic"; "retryAfterSec"; 60)
	End if 
	
	
	If (This:C1470._panicMode)
		If (Milliseconds:C459>=This:C1470._panicUntil)
			Use (This:C1470)
				This:C1470._panicMode:=False:C215
				This:C1470._panicReason:=""
			End use 
		Else 
			var $panicIP2 : Text
			$panicIP2:=This:C1470._extractIPFromHeader($headersRaw; $clientIP)
			
			If (cs:C1710.IPManager.me.isAllowlisted($panicIP2))
				Use (This:C1470.stats)
					This:C1470.stats.allowedRequests:=This:C1470.stats.allowedRequests+1
				End use 
				return New object:C1471("accept"; True:C214; "status"; 200; "reason"; "Allowed"; "retryAfterSec"; 0)
			End if 
			
			Use (This:C1470.stats)
				This:C1470.stats.blockedRequests:=This:C1470.stats.blockedRequests+1
				This:C1470.stats.panicRejections:=This:C1470.stats.panicRejections+1
			End use 
			return New object:C1471("accept"; False:C215; "status"; 503; "reason"; "Service Overload"; "retryAfterSec"; 60)
		End if 
	End if 
	
	
	var $maxHdrBytes : Integer
	$maxHdrBytes:=Num:C11(cs:C1710.ConfigManager.me.get("validation.maxHeaderBytes"))
	If ($maxHdrBytes<=0)
		$maxHdrBytes:=8192
	End if 
	If (Length:C16($headersRaw)>$maxHdrBytes)
		var $bloatIP : Text
		$bloatIP:=This:C1470._extractIPFromHeader($headersRaw; $clientIP)
		Use (This:C1470.stats)
			This:C1470.stats.blockedRequests:=This:C1470.stats.blockedRequests+1
			This:C1470.stats.invalidRequests:=This:C1470.stats.invalidRequests+1
		End use 
		cs:C1710.RequestLogger.me.log("HEADER_OVERFLOW"; $bloatIP; "AUTH"; $url; 400; \
			"Headers "+String:C10(Length:C16($headersRaw))+" bytes exceed "+String:C10($maxHdrBytes))
		cs:C1710.IPManager.me.blockIP($bloatIP; 300; "Header overflow attack")
		cs:C1710.AlertManager.me.raise("CRITICAL"; "HEADER_ATTACK"; "Header overflow blocked"; \
			"IP "+$bloatIP+" sent "+String:C10(Length:C16($headersRaw))+" bytes of headers"; \
			New object:C1471("ip"; $bloatIP; "bytes"; Length:C16($headersRaw)))
		return New object:C1471("accept"; False:C215; "status"; 400; "reason"; "Header Overflow"; "retryAfterSec"; 0)
	End if 
	
	
	var $ip : Text
	$ip:=This:C1470._extractIPFromHeader($headersRaw; $clientIP)
	
	var $now : Integer
	$now:=Milliseconds:C459
	
	var $ipMgr : cs:C1710.IPManager
	$ipMgr:=cs:C1710.IPManager.me
	var $logger : cs:C1710.RequestLogger
	$logger:=cs:C1710.RequestLogger.me
	var $alerts : cs:C1710.AlertManager
	$alerts:=cs:C1710.AlertManager.me
	var $config : cs:C1710.ConfigManager
	$config:=cs:C1710.ConfigManager.me
	
	
	This:C1470._trackRate($now)
	
	
	If (Not:C34(Bool:C1537($config.get("defenses.handler"))))
		Use (This:C1470.stats)
			This:C1470.stats.allowedRequests:=This:C1470.stats.allowedRequests+1
		End use 
		return New object:C1471("accept"; True:C214; "status"; 200; "reason"; "Allowed"; "retryAfterSec"; 0)
	End if 
	
	
	If ($ipMgr.isAllowlisted($ip))
		Use (This:C1470.stats)
			This:C1470.stats.allowedRequests:=This:C1470.stats.allowedRequests+1
		End use 
		return New object:C1471("accept"; True:C214; "status"; 200; "reason"; "Allowed"; "retryAfterSec"; 0)
	End if 
	
	
	If ($ipMgr.isBlocked($ip))
		var $blockReason : Text
		$blockReason:=""
		If (OB Is defined:C1231($ipMgr.blocklist; $ip))
			$blockReason:=String:C10($ipMgr.blocklist[$ip].reason)
		End if 
		Use (This:C1470.stats)
			This:C1470.stats.blockedRequests:=This:C1470.stats.blockedRequests+1
			If (($blockReason="Burst:@") | ($blockReason="Rate limit:@"))
				This:C1470.stats.rateLimitedRequests:=This:C1470.stats.rateLimitedRequests+1
			End if 
		End use 
		$logger.log("BLOCKED"; $ip; "AUTH"; $url; 403; "Blocklisted at auth hook")
		return New object:C1471("accept"; False:C215; "status"; 403; "reason"; "IP Blocked"; "retryAfterSec"; 0)
	End if 
	
	
	If (cs:C1710.Honeypot.me.isHoneypotURL($url))
		cs:C1710.Honeypot.me.recordHit($ip; $url; $headersRaw)
		Use (This:C1470.stats)
			This:C1470.stats.honeypotHits:=This:C1470.stats.honeypotHits+1
		End use 
		return New object:C1471("accept"; True:C214; "status"; 200; "reason"; "Allowed"; "retryAfterSec"; 0)
	End if 
	
	
	If (Bool:C1537($config.get("defenses.waf")))
		var $wafResult : Object
		$wafResult:=This:C1470._wafCheck($url; $ip)
		
		If (Not:C34($wafResult.valid))
			Use (This:C1470.stats)
				This:C1470.stats.wafRejections:=This:C1470.stats.wafRejections+1
				This:C1470.stats.blockedRequests:=This:C1470.stats.blockedRequests+1
			End use 
			$logger.log($wafResult.category; $ip; "AUTH"; $url; 403; $wafResult.reason)
			
			Case of 
				: ($wafResult.category="RECON_PROBE")
					$ipMgr.blockIP($ip; 600; "Recon probe: "+$wafResult.reason)
					$alerts.checkReconProbe($ip; $url; $wafResult.reason)
				: ($wafResult.category="TRAVERSAL")
					$ipMgr.blockIP($ip; 300; "Traversal: "+$url)
					$alerts.raise("CRITICAL"; "WAF"; "Traversal blocked"; \
						"IP "+$ip+" attempted path traversal"; \
						New object:C1471("ip"; $ip; "url"; $url))
				: ($wafResult.category="MALFORMED_URL")
					$alerts.checkWAFRejection($ip; "MALFORMED_URL"; $wafResult.reason)
			End case 
			
			return New object:C1471("accept"; False:C215; "status"; 403; "reason"; "WAF Rejection"; "retryAfterSec"; 0)
		End if 
	End if 
	
	If (Bool:C1537($config.get("defenses.rateLimit")))
		var $rl : Object
		$rl:=This:C1470._checkRate($ip; $now)
		
		If ($rl.burst)
			Use (This:C1470.stats)
				This:C1470.stats.blockedRequests:=This:C1470.stats.blockedRequests+1
				This:C1470.stats.rateLimitedRequests:=This:C1470.stats.rateLimitedRequests+1
			End use 
			$ipMgr.blockIP($ip; $rl.blockDurationSec; \
				"Burst: "+String:C10($rl.burstCount)+" req/"+String:C10($rl.burstWindowSec)+"s")
			$logger.log("BLOCKED"; $ip; "AUTH"; $url; 429; "Burst at auth hook")
			$alerts.checkBurstAlert($ip; $rl.burstCount; $rl.burstWindowSec)
			$alerts.checkBlocklistAlert($ipMgr.getStatus().blockedCount)
			return New object:C1471("accept"; False:C215; "status"; 429; "reason"; "Burst Detected"; "retryAfterSec"; $rl.blockDurationSec)
		End if 
		
		If ($rl.limited)
			Use (This:C1470.stats)
				This:C1470.stats.rateLimitedRequests:=This:C1470.stats.rateLimitedRequests+1
			End use 
			$logger.log("RATE_LIMITED"; $ip; "AUTH"; $url; 429; \
				String:C10($rl.count)+"/"+String:C10($rl.limit))
			$alerts.checkRateLimitAlert($ip; $rl.count; $rl.limit)
			
			$ipMgr.blockIP($ip; $rl.blockDurationSec; \
				"Rate limit: "+String:C10($rl.count)+"/"+String:C10($rl.limit))
			return New object:C1471("accept"; False:C215; "status"; 429; "reason"; "Rate Limited"; "retryAfterSec"; $rl.blockDurationSec)
		End if 
	End if 
	
	If (Bool:C1537($config.get("defenses.rateLimit")))
		var $global : Object
		$global:=This:C1470._checkGlobalRate($now)
		
		If ($global.exceeded)
			Use (This:C1470.stats)
				This:C1470.stats.globalRateHits:=This:C1470.stats.globalRateHits+1
				This:C1470.stats.rateLimitedRequests:=This:C1470.stats.rateLimitedRequests+1
			End use 
			$logger.log("GLOBAL_RATE_LIMIT"; $ip; "AUTH"; $url; 503; \
				"Global: "+String:C10($global.count)+"/"+String:C10($global.limit))
			$alerts.checkGlobalRateLimit($global.count; $global.limit)
			return New object:C1471("accept"; False:C215; "status"; 503; "reason"; "Global Rate Limit"; "retryAfterSec"; 60)
		End if 
	End if 
	
	Use (This:C1470.stats)
		This:C1470.stats.allowedRequests:=This:C1470.stats.allowedRequests+1
	End use 
	return New object:C1471("accept"; True:C214; "status"; 200; "reason"; "Allowed"; "retryAfterSec"; 0)
	
	
	
shared Function updateCPUSample($cpuPercent : Real; $processCount : Integer; \
$webProcessCount : Integer; $heaviest : Object)
	Use (This:C1470._cpuSample)
		This:C1470._cpuSample.cpuPercent:=$cpuPercent
		This:C1470._cpuSample.processCount:=$processCount
		This:C1470._cpuSample.webProcessCount:=$webProcessCount
		This:C1470._cpuSample.sampleTime:=Milliseconds:C459
		This:C1470._cpuSample.heaviestName:=String:C10($heaviest.name)
		This:C1470._cpuSample.heaviestPct:=Num:C11($heaviest.cpuUsage)
		
		This:C1470._cpuSample.history.push($cpuPercent)
		If (This:C1470._cpuSample.history.length>60)
			This:C1470._cpuSample.history.shift()
		End if 
	End use 
	
	
	
shared Function checkCPURising($currentCPU : Real)
	var $config : cs:C1710.ConfigManager
	$config:=cs:C1710.ConfigManager.me
	
	var $panicThresh : Real
	$panicThresh:=Num:C11($config.get("monitoring.cpuPanicTriggerAbove"))
	If ($panicThresh<=0)
		$panicThresh:=85
	End if 
	
	var $warnThresh : Real
	$warnThresh:=$panicThresh-15
	var $resetThresh : Real
	$resetThresh:=$panicThresh-25
	
	var $now : Integer
	$now:=Milliseconds:C459
	
	If ($currentCPU>=$warnThresh)
		Use (This:C1470)
			If (This:C1470._cpuRisingSince=0)
				This:C1470._cpuRisingSince:=$now
			End if 
		End use 
		
		If (($now-This:C1470._cpuRisingSince)>=10000)
			cs:C1710.AlertManager.me.raise("WARNING"; "CPU_RISING"; \
				"CPU climbing toward panic threshold"; \
				"CPU at "+String:C10($currentCPU; "###0.0")+"% — panic engages at "+\
				String:C10($panicThresh; "###0")+"%"; \
				New object:C1471("cpu"; $currentCPU; "warnThresh"; $warnThresh; \
				"panicThresh"; $panicThresh))
		End if 
	Else 
		If ($currentCPU<$resetThresh)
			Use (This:C1470)
				This:C1470._cpuRisingSince:=0
			End use 
		End if 
	End if 
	
	
shared Function checkCPUPanicTrigger($currentCPU : Real)
	var $config : cs:C1710.ConfigManager
	$config:=cs:C1710.ConfigManager.me
	
	If (Not:C34(Bool:C1537($config.get("monitoring.cpuPanicEnabled"))))
		return 
	End if 
	
	If (This:C1470._cpuPanicActive)
		var $liftThresh : Real
		$liftThresh:=Num:C11($config.get("monitoring.cpuPanicLiftBelow"))
		If ($liftThresh<=0)
			$liftThresh:=50
		End if 
		
		If ($currentCPU<$liftThresh) && (Milliseconds:C459>=This:C1470._cpuPanicUntil)
			Use (This:C1470)
				This:C1470._cpuPanicActive:=False:C215
			End use 
			cs:C1710.AlertManager.me.raise("INFO"; "CPU_PANIC"; "CPU panic lifted"; \
				"CPU dropped to "+String:C10($currentCPU; "###0.0")+"%"; \
				New object:C1471("cpu"; $currentCPU))
		End if 
		return 
	End if 
	
	var $triggerThresh : Real
	$triggerThresh:=Num:C11($config.get("monitoring.cpuPanicTriggerAbove"))
	If ($triggerThresh<=0)
		$triggerThresh:=85
	End if 
	
	If ($currentCPU>=$triggerThresh)
		var $minDur : Integer
		$minDur:=Num:C11($config.get("monitoring.cpuPanicMinDurationSec"))
		If ($minDur<=0)
			$minDur:=30
		End if 
		
		Use (This:C1470)
			This:C1470._cpuPanicActive:=True:C214
			This:C1470._cpuPanicUntil:=Milliseconds:C459+($minDur*1000)
		End use 
		
		cs:C1710.AlertManager.me.raise("CRITICAL"; "CPU_PANIC"; "CPU saturation"; \
			"4D CPU at "+String:C10($currentCPU; "###0.0")+"% — rejecting non-allowlisted traffic"; \
			New object:C1471("cpu"; $currentCPU; "threshold"; $triggerThresh))
	End if 
	
	
shared Function getCPU() : Real
	return This:C1470._cpuSample.cpuPercent
	
	
shared Function getCPUSample() : Object
	var $s : Object
	$s:=OB Copy:C1225(This:C1470._cpuSample)
	$s.panicActive:=This:C1470._cpuPanicActive
	$s.panicSecondsRemaining:=This:C1470._cpuPanicSecondsRemaining()
	
	If ($s.history.length>0)
		var $sum : Real
		$sum:=0
		var $i : Integer
		For ($i; 0; $s.history.length-1)
			$sum:=$sum+$s.history[$i]
		End for 
		$s.averageCPU:=$sum/$s.history.length
	Else 
		$s.averageCPU:=0
	End if 
	
	return $s
	
	
shared Function triggerPanicMode($durationSeconds : Integer; $reason : Text)
	If ($durationSeconds<=0)
		$durationSeconds:=Num:C11(cs:C1710.ConfigManager.me.get("panic.durationSeconds"))
		If ($durationSeconds<=0)
			$durationSeconds:=60
		End if 
	End if 
	
	Use (This:C1470)
		This:C1470._panicMode:=True:C214
		This:C1470._panicUntil:=Milliseconds:C459+($durationSeconds*1000)
		This:C1470._panicTriggeredAt:=Milliseconds:C459
		This:C1470._panicReason:=$reason
	End use 
	
	cs:C1710.AlertManager.me.raise("CRITICAL"; "PANIC"; "Panic mode engaged"; \
		"Server entered panic mode for "+String:C10($durationSeconds)+"s. "+$reason; \
		New object:C1471("duration"; $durationSeconds; "reason"; $reason))
	
	
shared Function liftPanicMode()
	Use (This:C1470)
		This:C1470._panicMode:=False:C215
		This:C1470._panicUntil:=0
		This:C1470._panicReason:=""
	End use 
	
	cs:C1710.AlertManager.me.raise("INFO"; "PANIC"; "Panic mode lifted"; \
		"Manually lifted by operator"; Null:C1517)
	
	
shared Function isPanicMode() : Boolean
	If (Not:C34(This:C1470._panicMode))
		return False:C215
	End if 
	If (Milliseconds:C459>=This:C1470._panicUntil)
		Use (This:C1470)
			This:C1470._panicMode:=False:C215
			This:C1470._panicReason:=""
		End use 
		return False:C215
	End if 
	return True:C214
	
	
shared Function getPanicState() : Object
	return New object:C1471(\
		"active"; This:C1470._panicMode; \
		"cpuPanicActive"; This:C1470._cpuPanicActive; \
		"secondsRemaining"; This:C1470._panicSecondsRemaining(); \
		"cpuPanicSecondsRemaining"; This:C1470._cpuPanicSecondsRemaining(); \
		"reason"; This:C1470._panicReason; \
		"triggeredAt"; This:C1470._panicTriggeredAt)
	
	
	
shared Function getGlobalRateCount() : Integer
	return This:C1470._globalWindow.length
	
	
shared Function handleRequest($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	
	var $gate : Object
	$gate:=This:C1470._gate($req)
	If (Not:C34($gate.accept))
		If ($gate.retryAfterSec>0)
			$resp.setHeader("Retry-After"; String:C10($gate.retryAfterSec))
		End if 
		return This:C1470._error($resp; $gate.status; $gate.reason; "")
	End if 
	
	var $ip : Text
	$ip:=$gate.ip
	
	var $config : cs:C1710.ConfigManager
	$config:=cs:C1710.ConfigManager.me
	
	If (Bool:C1537($config.get("defenses.shield")))
		var $valErr : Text
		$valErr:=This:C1470._validate($req)
		If ($valErr#"")
			Use (This:C1470.stats)
				This:C1470.stats.invalidRequests:=This:C1470.stats.invalidRequests+1
			End use 
			
			cs:C1710.RequestLogger.me.log("INVALID"; $ip; $req.verb; $req.url; 400; $valErr; $req.getText())
			return This:C1470._error($resp; 400; "Bad Request"; $valErr)
		End if 
	End if 
	
	return This:C1470._success($resp; $req; $ip; 999; 999)
	
	
shared Function handleHealthCheck($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	
	var $gate : Object
	$gate:=This:C1470._gate($req)
	If (Not:C34($gate.accept))
		If ($gate.retryAfterSec>0)
			$resp.setHeader("Retry-After"; String:C10($gate.retryAfterSec))
		End if 
		return This:C1470._error($resp; $gate.status; $gate.reason; "")
	End if 
	
	var $body : Object
	$body:=New object:C1471(\
		"status"; "healthy"; \
		"timestamp"; Timestamp:C1445; \
		"uptime"; (Milliseconds:C459-This:C1470.stats.startTime)\1000; \
		"cpu"; This:C1470._cpuSample.cpuPercent; \
		"version"; "4D v21.0 LTS")
	
	$resp.setBody(JSON Stringify:C1217($body))
	$resp.setHeader("Content-Type"; "application/json")
	$resp.setHeader("Cache-Control"; "no-store")
	$resp.setStatus(200)
	return $resp
	
	
shared Function handleHeavyTest($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	
	var $gate : Object
	$gate:=This:C1470._gate($req)
	If (Not:C34($gate.accept))
		If ($gate.retryAfterSec>0)
			$resp.setHeader("Retry-After"; String:C10($gate.retryAfterSec))
		End if 
		return This:C1470._error($resp; $gate.status; $gate.reason; "")
	End if 
	
	var $r : Real
	$r:=0
	var $i : Integer
	For ($i; 1; 500000)
		$r:=$r+(Cos:C18($i)*Sin:C17($i))
	End for 
	
	$resp.setBody(JSON Stringify:C1217(New object:C1471("result"; $r; "iterations"; 500000)))
	$resp.setHeader("Content-Type"; "application/json")
	$resp.setStatus(200)
	return $resp
	
	
shared Function getPublicStats() : Object
	var $s : Object
	$s:=OB Copy:C1225(This:C1470.stats)
	$s.uptime:=(Milliseconds:C459-This:C1470.stats.startTime)\1000
	$s.currentRate:=This:C1470._minuteCount
	$s.trackedIPs:=OB Keys:C1719(This:C1470._windows).length
	$s.globalWindowSize:=This:C1470._globalWindow.length
	$s.realCPU:=This:C1470._cpuSample.cpuPercent
	
	If (This:C1470._rateHistory.length>0)
		var $sum : Real
		$sum:=0
		var $r : Integer
		For ($r; 0; This:C1470._rateHistory.length-1)
			$sum:=$sum+This:C1470._rateHistory[$r].rate
		End for 
		$s.averageRate:=$sum/This:C1470._rateHistory.length
	Else 
		$s.averageRate:=0
	End if 
	
	return $s
	
	
shared Function getRateHistory() : Collection
	return This:C1470._rateHistory.copy()
	
	
shared Function resetAll()
	Use (This:C1470.stats)
		This:C1470.stats.totalRequests:=0
		This:C1470.stats.allowedRequests:=0
		This:C1470.stats.blockedRequests:=0
		This:C1470.stats.rateLimitedRequests:=0
		This:C1470.stats.invalidRequests:=0
		This:C1470.stats.wafRejections:=0
		This:C1470.stats.globalRateHits:=0
		This:C1470.stats.panicRejections:=0
		This:C1470.stats.honeypotHits:=0
		This:C1470.stats.startTime:=Milliseconds:C459
	End use 
	This:C1470._minuteCount:=0
	This:C1470._minuteStart:=Milliseconds:C459
	Use (This:C1470)
		This:C1470._rateHistory:=New shared collection:C1527
		This:C1470._windows:=New shared object:C1526
		This:C1470._globalWindow:=New shared collection:C1527
	End use 
	
	
	
shared Function sweepWindows()
	var $keys : Collection
	$keys:=OB Keys:C1719(This:C1470._windows)
	var $removed : Integer
	$removed:=0
	Use (This:C1470._windows)
		var $i : Integer
		For ($i; 0; $keys.length-1)
			var $w : Object
			$w:=This:C1470._windows[$keys[$i]]
			If ($w#Null:C1517) && ($w.ts#Null:C1517) && ($w.bts#Null:C1517)
				If (($w.ts.length=0) && ($w.bts.length=0))
					OB REMOVE:C1226(This:C1470._windows; $keys[$i])
					$removed:=$removed+1
				End if 
			End if 
		End for 
	End use 
	If ($removed>0)
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[DOSGUARD] Swept "+String:C10($removed)+" idle IP windows"; \
			Information message:K38:1)
	End if 
	
	
	
shared Function _isMasterOn() : Boolean
	var $cfg : Variant
	$cfg:=cs:C1710.ConfigManager.me.get("defenses.master")
	If ($cfg=Null:C1517)
		return True:C214
	End if 
	return Bool:C1537($cfg)
	
	
Function _panicSecondsRemaining() : Integer
	If (Not:C34(This:C1470._panicMode))
		return 0
	End if 
	var $ms : Integer
	$ms:=This:C1470._panicUntil-Milliseconds:C459
	If ($ms<0)
		return 0
	End if 
	return $ms\1000
	
	
Function _cpuPanicSecondsRemaining() : Integer
	If (Not:C34(This:C1470._cpuPanicActive))
		return 0
	End if 
	var $ms : Integer
	$ms:=This:C1470._cpuPanicUntil-Milliseconds:C459
	If ($ms<0)
		return 0
	End if 
	return $ms\1000
	
	
Function _checkRate($ip : Text; $now : Integer) : Object
	var $windowMs; $burstWinMs; $maxReq; $burstThresh; $blockDurSec; $windowSec; $burstWinSec : Integer
	
	If ($ip="")
		$ip:="anon:unknown"
	End if 
	
	$maxReq:=Num:C11(cs:C1710.ConfigManager.me.get("rateLimiting.maxRequests"))
	$windowSec:=Num:C11(cs:C1710.ConfigManager.me.get("rateLimiting.windowSeconds"))
	$burstThresh:=Num:C11(cs:C1710.ConfigManager.me.get("rateLimiting.burstThreshold"))
	$burstWinSec:=Num:C11(cs:C1710.ConfigManager.me.get("rateLimiting.burstWindowSeconds"))
	$blockDurSec:=Num:C11(cs:C1710.ConfigManager.me.get("rateLimiting.blockDurationSeconds"))
	
	If ($maxReq<=0)
		$maxReq:=100
	End if 
	If ($windowSec<=0)
		$windowSec:=60
	End if 
	If ($burstThresh<=0)
		$burstThresh:=20
	End if 
	If ($burstWinSec<=0)
		$burstWinSec:=5
	End if 
	If ($blockDurSec<=0)
		$blockDurSec:=300
	End if 
	
	$windowMs:=$windowSec*1000
	$burstWinMs:=$burstWinSec*1000
	
	var $result : Object
	$result:=New object:C1471("limited"; False:C215; "burst"; False:C215; \
		"count"; 0; "remaining"; 0; "retryAfterSec"; 0; \
		"limit"; $maxReq; "burstCount"; 0; "burstWindowSec"; $burstWinSec; \
		"blockDurationSec"; $blockDurSec)
	
	
	If (Not:C34(OB Is defined:C1231(This:C1470._windows; $ip)))
		Use (This:C1470._windows)
			If (Not:C34(OB Is defined:C1231(This:C1470._windows; $ip)))
				var $newWinTemp : Object
				$newWinTemp:=New object:C1471("ts"; New collection:C1472; "bts"; New collection:C1472)
				This:C1470._windows[$ip]:=OB Copy:C1225($newWinTemp; ck shared:K85:29; This:C1470._windows)
			End if 
		End use 
	End if 
	
	var $w : Object
	$w:=This:C1470._windows[$ip]
	
	
	var $cutoff : Integer
	$cutoff:=$now-$windowMs
	var $tsLen : Integer
	Use ($w.ts)
		While (($w.ts.length>0) && ($w.ts[0]<$cutoff))
			$w.ts.shift()
		End while 
		$w.ts.push($now)
		$tsLen:=$w.ts.length
	End use 
	
	$cutoff:=$now-$burstWinMs
	var $btsLen : Integer
	Use ($w.bts)
		While (($w.bts.length>0) && ($w.bts[0]<$cutoff))
			$w.bts.shift()
		End while 
		$w.bts.push($now)
		$btsLen:=$w.bts.length
	End use 
	
	$result.count:=$tsLen
	$result.burstCount:=$btsLen
	
	
	If (($btsLen>=Int:C8($burstThresh*0.75)) && ($btsLen<$burstThresh))
		cs:C1710.AlertManager.me.raise("WARNING"; "BURST_RISING"; \
			"IP approaching burst threshold"; \
			"IP "+$ip+" at "+String:C10($btsLen)+"/"+String:C10($burstThresh)+\
			" requests in "+String:C10($burstWinSec)+"s window"; \
			New object:C1471("ip"; $ip; "burstCount"; $btsLen; "burstThresh"; $burstThresh))
	End if 
	
	If ($result.burstCount>=$burstThresh)
		$result.burst:=True:C214
		$result.retryAfterSec:=$blockDurSec
		return $result
	End if 
	
	If ($result.count>$maxReq)
		$result.limited:=True:C214
		$result.remaining:=0
		If ($w.ts.length>0)
			$result.retryAfterSec:=(($w.ts[0]+$windowMs)-$now)\1000
			If ($result.retryAfterSec<1)
				$result.retryAfterSec:=1
			End if 
		Else 
			$result.retryAfterSec:=$windowSec
		End if 
	Else 
		$result.remaining:=$maxReq-$result.count
	End if 
	
	return $result
	
	
Function _checkGlobalRate($now : Integer) : Object
	var $cap : Integer
	$cap:=Num:C11(cs:C1710.ConfigManager.me.get("rateLimiting.globalMaxPerMinute"))
	If ($cap<=0)
		$cap:=10000
	End if 
	
	var $cutoff : Integer
	$cutoff:=$now-60000
	
	Use (This:C1470._globalWindow)
		While ((This:C1470._globalWindow.length>0) && (This:C1470._globalWindow[0]<$cutoff))
			This:C1470._globalWindow.shift()
		End while 
		This:C1470._globalWindow.push($now)
	End use 
	
	var $count : Integer
	$count:=This:C1470._globalWindow.length
	
	
	If (($count>=($cap\2)) && ($count<=$cap))
		cs:C1710.AlertManager.me.raise("WARNING"; "GLOBAL_RATE_RISING"; \
			"Global request rate climbing"; \
			"Global rate "+String:C10($count)+" req/min — 50% of cap "+String:C10($cap); \
			New object:C1471("count"; $count; "cap"; $cap))
	End if 
	
	return New object:C1471(\
		"count"; $count; \
		"limit"; $cap; \
		"exceeded"; ($count>$cap))
	
	
Function _wafCheck($url : Text; $ip : Text) : Object
	var $result : Object
	$result:=New object:C1471("valid"; True:C214; "category"; ""; "reason"; "")
	
	If (Position:C15("\\"; $url)>0)
		$result.valid:=False:C215
		$result.category:="MALFORMED_URL"
		$result.reason:="Backslash in URL"
		return $result
	End if 
	
	
	var $lower : Text
	$lower:=Lowercase:C14($url)
	If ((Position:C15(".."; $lower)>0) | (Position:C15("%2e%2e"; $lower)>0) | (Position:C15("%252e"; $lower)>0))
		$result.valid:=False:C215
		$result.category:="TRAVERSAL"
		$result.reason:="Traversal pattern in raw URL"
		return $result
	End if 
	
	var $patterns : Collection
	$patterns:=cs:C1710.ConfigManager.me.get("waf.reconPatterns")
	If ($patterns#Null:C1517)
		var $lowerURL : Text
		$lowerURL:=Lowercase:C14($url)
		var $p : Integer
		For ($p; 0; $patterns.length-1)
			If (Position:C15(Lowercase:C14(String:C10($patterns[$p])); $lowerURL)>0)
				$result.valid:=False:C215
				$result.category:="RECON_PROBE"
				$result.reason:=String:C10($patterns[$p])
				return $result
			End if 
		End for 
	End if 
	
	var $canon : Text
	$canon:=cs:C1710.URLNormalizer.me.canonicalize($url)
	
	If ($canon="")
		$result.valid:=False:C215
		$result.category:="TRAVERSAL"
		$result.reason:="Canonicalization failed"
		return $result
	End if 
	
	If (Not:C34(cs:C1710.URLNormalizer.me.isSafe($canon)))
		$result.valid:=False:C215
		$result.category:="MALFORMED_URL"
		$result.reason:="isSafe() rejected"
		return $result
	End if 
	
	return $result
	
	
Function _validate($req : 4D:C1709.IncomingMessage) : Text
	var $maxURL : Integer
	$maxURL:=Num:C11(cs:C1710.ConfigManager.me.get("validation.maxURLLength"))
	If ($maxURL<=0)
		$maxURL:=2048
	End if 
	If (Length:C16($req.url)>$maxURL)
		return "URL exceeds "+String:C10($maxURL)+" chars"
	End if 
	
	If (($req.verb="POST") | ($req.verb="PUT") | ($req.verb="PATCH"))
		var $cl : Text
		$cl:=$req.getHeader("Content-Length")
		If ($cl#"")
			var $maxBody : Integer
			$maxBody:=Num:C11(cs:C1710.ConfigManager.me.get("validation.maxBodySizeMB"))
			If ($maxBody<=0)
				$maxBody:=10
			End if 
			If (Num:C11($cl)>($maxBody*1048576))
				return "Body exceeds "+String:C10($maxBody)+" MB"
			End if 
		End if 
	End if 
	
	If (Bool:C1537(cs:C1710.ConfigManager.me.get("validation.requireUserAgent")))
		If ($req.getHeader("User-Agent")="")
			return "Missing User-Agent"
		End if 
	End if 
	
	return ""
	
	
Function _trackRate($now : Integer)
	This:C1470._minuteCount:=This:C1470._minuteCount+1
	If (($now-This:C1470._minuteStart)>=60000)
		var $historyEntryTemp : Object
		$historyEntryTemp:=New object:C1471("ts"; This:C1470._minuteStart; "rate"; This:C1470._minuteCount)
		Use (This:C1470._rateHistory)
			This:C1470._rateHistory.push(OB Copy:C1225($historyEntryTemp; ck shared:K85:29; This:C1470._rateHistory))
			If (This:C1470._rateHistory.length>60)
				This:C1470._rateHistory.shift()
			End if 
		End use 
		
		If (This:C1470._rateHistory.length>=3)
			var $sum : Real
			$sum:=0
			var $r : Integer
			For ($r; 0; This:C1470._rateHistory.length-2)
				$sum:=$sum+This:C1470._rateHistory[$r].rate
			End for 
			cs:C1710.AlertManager.me.checkTrafficSpike(This:C1470._minuteCount; \
				$sum/(This:C1470._rateHistory.length-1))
		End if 
		
		This:C1470._minuteCount:=0
		This:C1470._minuteStart:=$now
	End if 
	
	
	
	
Function _gate($req : 4D:C1709.IncomingMessage) : Object
	
	var $tokenConsumed : Boolean
	$tokenConsumed:=False:C215
	var $tokenAccept : Boolean
	$tokenAccept:=False:C215
	var $tokenIP : Text
	$tokenIP:=""
	var $tokenStatus : Integer
	$tokenStatus:=403
	var $tokenReason : Text
	$tokenReason:="Unknown"
	var $tokenRetryAfterSec : Integer
	$tokenRetryAfterSec:=0
	
	If (Session:C1714.storage.authData#Null:C1517)
		Use (Session:C1714.storage.authData)
			var $ms : Integer
			$ms:=Num:C11(Session:C1714.storage.authData._authMs)
			var $elapsed : Integer
			$elapsed:=Milliseconds:C459-$ms
			
			var $tokenMatch : Boolean
			$tokenMatch:=(($ms>0) & ($elapsed>=0) & ($elapsed<500) & (String:C10(Session:C1714.storage.authData._authUrl)=$req.url))
			If ($tokenMatch)
				$tokenAccept:=Bool:C1537(Session:C1714.storage.authData._authAccept)
				$tokenIP:=String:C10(Session:C1714.storage.authData.clientIP)
				If (Session:C1714.storage.authData._authStatus#Null:C1517)
					$tokenStatus:=Num:C11(Session:C1714.storage.authData._authStatus)
					If ($tokenStatus=0)
						$tokenStatus:=403
					End if 
				End if 
				If (Session:C1714.storage.authData._authReason#Null:C1517)
					$tokenReason:=String:C10(Session:C1714.storage.authData._authReason)
					If ($tokenReason="")
						$tokenReason:="Unknown"
					End if 
				End if 
				If (Session:C1714.storage.authData._authRetryAfterSec#Null:C1517)
					$tokenRetryAfterSec:=Num:C11(Session:C1714.storage.authData._authRetryAfterSec)
				End if 
				Session:C1714.storage.authData._authMs:=0
				$tokenConsumed:=True:C214
			End if 
		End use 
	End if 
	
	If ($tokenConsumed)
		return New object:C1471(\
			"accept"; $tokenAccept; \
			"ip"; $tokenIP; \
			"status"; $tokenStatus; \
			"reason"; $tokenReason; \
			"retryAfterSec"; $tokenRetryAfterSec)
	End if 
	
	
	var $hdr : Text
	$hdr:=This:C1470._serializeHeaders($req)
	var $ip : Text
	$ip:=This:C1470._extractIP($req)
	
	var $sonarResult : Object
	$sonarResult:=cs:C1710.Sonar.me.intercept($ip; $req.url; $hdr)
	
	If (Session:C1714.storage.authData=Null:C1517)
		Use (Session:C1714.storage)
			Session:C1714.storage.authData:=New shared object:C1526
		End use 
	End if 
	Use (Session:C1714.storage.authData)
		Session:C1714.storage.authData.clientIP:=$ip
		Session:C1714.storage.authData.clientType:=String:C10($sonarResult.clientType)
		Session:C1714.storage.authData.clientFamily:=String:C10($sonarResult.clientFamily)
	End use 
	
	var $defenseResult : Object
	$defenseResult:=This:C1470.authenticateRequest($req.url; $hdr; $ip)
	
	var $accept : Boolean
	$accept:=$defenseResult.accept
	return New object:C1471(\
		"accept"; $accept; \
		"ip"; $ip; \
		"status"; $defenseResult.status; \
		"reason"; $defenseResult.reason; \
		"retryAfterSec"; $defenseResult.retryAfterSec)
	
	
Function _serializeHeaders($req : 4D:C1709.IncomingMessage) : Text
	
	var $out : Text
	$out:=""
	If ($req.headers=Null:C1517)
		return $out
	End if 
	var $keys : Collection
	$keys:=OB Keys:C1719($req.headers)
	var $i : Integer
	For ($i; 0; $keys.length-1)
		$out:=$out+$keys[$i]+": "+String:C10($req.headers[$keys[$i]])+Char:C90(13)+Char:C90(10)
	End for 
	return $out
	
	
Function _extractIP($req : 4D:C1709.IncomingMessage) : Text
	
	var $storedIP : Text
	$storedIP:=String:C10(Session:C1714.storage.authData.clientIP)
	
	var $headersRaw : Text
	$headersRaw:=""
	var $xff : Text
	$xff:=$req.getHeader("X-Forwarded-For")
	If ($xff#"")
		$headersRaw:="X-Forwarded-For: "+$xff+Char:C90(13)+Char:C90(10)
	End if 
	var $xri : Text
	$xri:=$req.getHeader("X-Real-IP")
	If ($xri#"")
		$headersRaw:=$headersRaw+"X-Real-IP: "+$xri+Char:C90(13)+Char:C90(10)
	End if 
	var $resolved : Text
	$resolved:=This:C1470._extractIPFromHeader($headersRaw; $storedIP)
	
	If ($resolved="")
		var $remote : Text
		$remote:=Try(String:C10($req.remoteAddress))
		If ($remote=Null:C1517) | ($remote="")
			$remote:=""
		End if 
		If ($remote#"")
			$resolved:=$remote
		End if 
	End if 
	
	If ($resolved="")
		var $ua : Text
		var $acc : Text
		var $accLang : Text
		$ua:=String:C10($req.getHeader("User-Agent"))
		$acc:=String:C10($req.getHeader("Accept"))
		$accLang:=String:C10($req.getHeader("Accept-Language"))
		var $fingerprint : Text
		$fingerprint:=$ua+"|"+$acc+"|"+$accLang
		If ($fingerprint#"||")
			var $hex : Text
			$hex:=Lowercase:C14(Generate digest:C1147($fingerprint; SHA256 digest:K66:4))
			$resolved:="anon:"+Substring:C12($hex; 1; 16)
		End if 
	End if 
	
	If ($resolved="")
		$resolved:="anon:unknown"
	End if 
	
	return This:C1470._normalizeIP($resolved)
	
	
Function _extractIPFromHeader($headersRaw : Text; $remoteAddress : Text) : Text
	var $trusted : Collection
	$trusted:=cs:C1710.ConfigManager.me.get("security.trustedProxies")
	If ($trusted=Null:C1517)
		$trusted:=New collection:C1472
	End if 
	
	var $remoteIsTrusted : Boolean
	$remoteIsTrusted:=False:C215
	var $t : Integer
	For ($t; 0; $trusted.length-1)
		If (String:C10($trusted[$t])=$remoteAddress)
			$remoteIsTrusted:=True:C214
		End if 
	End for 
	
	If ($remoteIsTrusted)
		var $xff : Text
		$xff:=This:C1470._parseHeader($headersRaw; "X-Forwarded-For")
		If ($xff#"")
			var $comma : Integer
			$comma:=Position:C15(","; $xff)
			If ($comma>0)
				return This:C1470._normalizeIP(Trim:C1853(Substring:C12($xff; 1; $comma-1)))
			End if 
			return This:C1470._normalizeIP(Trim:C1853($xff))
		End if 
		
		var $xri : Text
		$xri:=This:C1470._parseHeader($headersRaw; "X-Real-IP")
		If ($xri#"")
			return This:C1470._normalizeIP(Trim:C1853($xri))
		End if 
	End if 
	
	return This:C1470._normalizeIP($remoteAddress)
	
	
Function _parseHeader($headersRaw : Text; $name : Text) : Text
	var $lines : Collection
	$lines:=Split string:C1554($headersRaw; Char:C90(13)+Char:C90(10))
	var $prefix : Text
	$prefix:=Lowercase:C14($name)+":"
	var $i : Integer
	For ($i; 0; $lines.length-1)
		var $line : Text
		$line:=Lowercase:C14(String:C10($lines[$i]))
		If (Position:C15($prefix; $line)=1)
			return Trim:C1853(Substring:C12(String:C10($lines[$i]); Length:C16($name)+2))
		End if 
	End for 
	return ""
	
	
Function _normalizeIP($raw : Text) : Text
	var $ip : Text
	$ip:=Trim:C1853(String:C10($raw))
	
	If ($ip="")
		return ""
	End if 
	
	If (Position:C15("anon:"; $ip)=1)
		return $ip
	End if 
	
	If (Substring:C12($ip; 1; 1)="[")
		var $close : Integer
		$close:=Position:C15("]"; $ip)
		If ($close>2)
			$ip:=Substring:C12($ip; 2; $close-2)
		End if 
	End if 
	
	var $pct : Integer
	$pct:=Position:C15("%"; $ip)
	If ($pct>0)
		$ip:=Substring:C12($ip; 1; $pct-1)
	End if 
	
	If ($ip="::1") | ($ip="0:0:0:0:0:0:0:1")
		return "127.0.0.1"
	End if 
	If ($ip="::") | ($ip="0:0:0:0:0:0:0:0")
		return "0.0.0.0"
	End if 
	
	
	var $lower : Text
	$lower:=Lowercase:C14($ip)
	If (Position:C15("::ffff:"; $lower)=1)
		var $tail : Text
		$tail:=Substring:C12($ip; 8)
		If (This:C1470._isIPv4($tail))
			return $tail
		End if 
	End if 
	If (Position:C15("0:0:0:0:0:ffff:"; $lower)=1)
		var $tail2 : Text
		$tail2:=Substring:C12($ip; 16)
		If (This:C1470._isIPv4($tail2))
			return $tail2
		End if 
	End if 
	
	If (This:C1470._isIPv4($ip))
		return $ip
	End if 
	var $oneColon : Integer
	$oneColon:=Position:C15(":"; $ip)
	If ($oneColon>0) & (Position:C15(":"; $ip; $oneColon+1)=0)
		var $left : Text
		$left:=Substring:C12($ip; 1; $oneColon-1)
		If (This:C1470._isIPv4($left))
			return $left
		End if 
	End if 
	
	return $ip
	
Function _isIPv4($s : Text) : Boolean
	var $parts : Collection
	$parts:=Split string:C1554($s; ".")
	If ($parts.length#4)
		return False:C215
	End if 
	var $i : Integer
	For ($i; 0; 3)
		var $p : Text
		$p:=String:C10($parts[$i])
		If ($p="") | (Length:C16($p)>3)
			return False:C215
		End if 
		var $j : Integer
		For ($j; 1; Length:C16($p))
			var $c : Text
			$c:=Substring:C12($p; $j; 1)
			If (Position:C15($c; "0123456789")=0)
				return False:C215
			End if 
		End for 
		var $n : Integer
		$n:=Num:C11($p)
		If ($n<0) | ($n>255)
			return False:C215
		End if 
	End for 
	return True:C214
	
	
	
Function _error($resp : 4D:C1709.OutgoingMessage; $code : Integer; $err : Text; $msg : Text) : 4D:C1709.OutgoingMessage
	var $b : Object
	$b:=New object:C1471("status"; "error"; "code"; $code; "error"; $err; \
		"message"; $msg; "timestamp"; Timestamp:C1445)
	$resp.setBody(JSON Stringify:C1217($b))
	$resp.setHeader("Content-Type"; "application/json")
	$resp.setHeader("Cache-Control"; "no-store")
	$resp.setStatus($code)
	return $resp
	
	
Function _success($resp : 4D:C1709.OutgoingMessage; $req : 4D:C1709.IncomingMessage; $ip : Text; $remaining : Integer; $limit : Integer) : 4D:C1709.OutgoingMessage
	var $b : Object
	$b:=New object:C1471("status"; "success"; \
		"request"; New object:C1471("method"; $req.verb; "url"; $req.url; "clientIP"; $ip); \
		"rateLimit"; New object:C1471("limit"; $limit; "remaining"; $remaining))
	$resp.setBody(JSON Stringify:C1217($b))
	$resp.setHeader("Content-Type"; "application/json")
	$resp.setStatus(200)
	return $resp