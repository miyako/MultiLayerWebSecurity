//%attributes = {}



var $guard : cs:C1710.DoSGuard
var $ipMgr : cs:C1710.IPManager
var $config : cs:C1710.ConfigManager
var $alerts : cs:C1710.AlertManager
var $stats : Object
var $ipStatus : Object
var $continue : Boolean

$guard:=cs:C1710.DoSGuard.me
$ipMgr:=cs:C1710.IPManager.me
$config:=cs:C1710.ConfigManager.me
$alerts:=cs:C1710.AlertManager.me
$continue:=True:C214

While ($continue)
	
	$stats:=$guard.getPublicStats()
	$ipStatus:=$ipMgr.getStatus()
	
	var $maxReq; $windowSec; $burstThresh; $burstWin; $blockDur : Variant
	$maxReq:=$config.get("rateLimiting.maxRequests")
	$windowSec:=$config.get("rateLimiting.windowSeconds")
	$burstThresh:=$config.get("rateLimiting.burstThreshold")
	$burstWin:=$config.get("rateLimiting.burstWindowSeconds")
	$blockDur:=$config.get("rateLimiting.blockDurationSeconds")
	
	var $handlerOn; $shieldOn; $rateOn; $wafOn : Boolean
	$handlerOn:=Bool:C1537($config.get("defenses.handler"))
	$shieldOn:=Bool:C1537($config.get("defenses.shield"))
	$rateOn:=Bool:C1537($config.get("defenses.rateLimit"))
	$wafOn:=Bool:C1537($config.get("defenses.waf"))
	
	var $reconPatterns : Collection
	$reconPatterns:=$config.get("waf.reconPatterns")
	var $reconCount : Integer
	$reconCount:=Choose:C955($reconPatterns=Null:C1517; 0; $reconPatterns.length)
	
	ALERT:C41("=== DoS Guard Admin Panel ===\n\n"+\
		"--- Defense Layers ---\n"+\
		"Handler:    "+Choose:C955($handlerOn; "ENGAGED"; "DISENGAGED")+"\n"+\
		"Shield:     "+Choose:C955($shieldOn; "ENGAGED"; "DISENGAGED")+"\n"+\
		"WAF:        "+Choose:C955($wafOn; "ENGAGED"; "DISENGAGED")+" ("+String:C10($reconCount)+" recon patterns)\n"+\
		"RateLimit:  "+Choose:C955($rateOn; "ENGAGED"; "DISENGAGED")+"\n\n"+\
		"--- Guard Stats ---\n"+\
		"Total requests:    "+String:C10($stats.totalRequests)+"\n"+\
		"Allowed:           "+String:C10($stats.allowedRequests)+"\n"+\
		"Blocked:           "+String:C10($stats.blockedRequests)+"\n"+\
		"Rate limited:      "+String:C10($stats.rateLimitedRequests)+"\n"+\
		"Invalid:           "+String:C10($stats.invalidRequests)+"\n"+\
		"WAF rejections:    "+String:C10($stats.wafRejections)+"\n"+\
		"Current rate:      "+String:C10($stats.currentRate)+" req/min\n"+\
		"Tracked IPs:       "+String:C10($stats.trackedIPs)+"\n"+\
		"Uptime:            "+String:C10($stats.uptime)+"s\n\n"+\
		"--- IP Status ---\n"+\
		"Blocked IPs:       "+String:C10($ipStatus.blockedCount)+"\n"+\
		"Permanent blocks:  "+String:C10($ipStatus.permanentBlocks)+"\n"+\
		"Allowlisted IPs:   "+String:C10($ipStatus.allowedCount)+"\n"+\
		"Total strikes:     "+String:C10($ipStatus.totalStrikes)+"\n\n"+\
		"--- Rate Config ---\n"+\
		"Rate limit: "+String:C10($maxReq)+"/"+String:C10($windowSec)+"s\n"+\
		"Burst:      "+String:C10($burstThresh)+"/"+String:C10($burstWin)+"s\n"+\
		"Block duration: "+String:C10($blockDur)+"s")
	
	CONFIRM:C162("View blocked IP list?")
	If (OK=1)
		var $blocklist : Collection
		$blocklist:=$ipMgr.getBlocklist()
		If ($blocklist.length>0)
			var $ipList : Text
			var $j : Integer
			$ipList:=""
			For ($j; 0; $blocklist.length-1)
				$ipList:=$ipList+$blocklist[$j].ip+" ("+$blocklist[$j].timeRemaining+") - "+$blocklist[$j].reason+"\n"
			End for 
			ALERT:C41("Blocked IPs ("+String:C10($blocklist.length)+"):\n\n"+$ipList)
			
			CONFIRM:C162("Unblock all IPs?")
			If (OK=1)
				$ipMgr.clearBlocklist()
				ALERT:C41("All IPs have been unblocked.")
			End if 
		Else 
			ALERT:C41("No IPs currently blocked.")
		End if 
	End if 
	
	CONFIRM:C162("WAF is "+Choose:C955($wafOn; "ENGAGED"; "DISENGAGED")+". Toggle?")
	If (OK=1)
		$config.set("defenses.waf"; Not:C34($wafOn))
		ALERT:C41("WAF is now "+Choose:C955(Not:C34($wafOn); "ENGAGED"; "DISENGAGED")+".")
	End if 
	
	CONFIRM:C162("Review WAF recon patterns? ("+String:C10($reconCount)+" active)")
	If (OK=1)
		If ($reconCount>0)
			var $patternList : Text
			$patternList:=""
			var $p : Integer
			For ($p; 0; $reconPatterns.length-1)
				$patternList:=$patternList+String:C10($reconPatterns[$p])+"\n"
				If ($p=20)
					$patternList:=$patternList+"... (truncated)"
					$p:=$reconPatterns.length
				End if 
			End for 
			ALERT:C41("Recon patterns:\n\n"+$patternList)
			
			CONFIRM:C162("Add a new recon pattern?")
			If (OK=1)
				var $newPattern : Text
				$newPattern:=Request:C163("Enter new recon pattern (e.g. /phpinfo):"; "")
				If ((OK=1) & ($newPattern#""))
					var $updated : Collection
					$updated:=$reconPatterns.copy()
					$updated.push($newPattern)
					$config.set("waf.reconPatterns"; $updated)
					ALERT:C41("Pattern added. "+String:C10($updated.length)+" total.")
				End if 
			End if 
		Else 
			ALERT:C41("No recon patterns configured.")
		End if 
	End if 
	
	CONFIRM:C162("Reset all guard stats and tracking data?")
	If (OK=1)
		$guard.resetAll()
		cs:C1710.RequestLogger.me.clear()
		cs:C1710.AlertManager.me.clear()
		ALERT:C41("Guard stats, request log, and alerts have been reset.")
	End if 
	
	CONFIRM:C162("Clear WAF per-IP rejection counters?")
	If (OK=1)
		$alerts.resetWAFCounters("")
		ALERT:C41("WAF counters cleared.")
	End if 
	
	CONFIRM:C162("Clear all IP strike records?")
	If (OK=1)
		$ipMgr.clearAllStrikes()
		ALERT:C41("All strike records cleared.")
	End if 
	
	CONFIRM:C162("Adjust rate limit? (Current: "+String:C10($maxReq)+"/"+String:C10($windowSec)+"s)")
	If (OK=1)
		var $newLimit : Text
		$newLimit:=Request:C163("Enter new max requests per window:"; String:C10($maxReq))
		If (OK=1)
			$config.set("rateLimiting.maxRequests"; Num:C11($newLimit))
			ALERT:C41("Rate limit updated to "+$newLimit+" requests per window.")
		End if 
	End if 
	
	CONFIRM:C162("Adjust burst threshold? (Current: "+String:C10($burstThresh)+"/"+String:C10($burstWin)+"s)")
	If (OK=1)
		var $newBurst : Text
		$newBurst:=Request:C163("Enter new burst threshold:"; String:C10($burstThresh))
		If (OK=1)
			$config.set("rateLimiting.burstThreshold"; Num:C11($newBurst))
			ALERT:C41("Burst threshold updated to "+$newBurst+".")
		End if 
	End if 
	
	CONFIRM:C162("Adjust block duration? (Current: "+String:C10($blockDur)+"s)")
	If (OK=1)
		var $newDur : Text
		$newDur:=Request:C163("Enter new block duration (seconds):"; String:C10($blockDur))
		If (OK=1)
			$config.set("rateLimiting.blockDurationSeconds"; Num:C11($newDur))
			ALERT:C41("Block duration updated to "+$newDur+"s.")
		End if 
	End if 
	
	CONFIRM:C162("Continue administering DoS Guard?")
	$continue:=(OK=1)
	
End while 