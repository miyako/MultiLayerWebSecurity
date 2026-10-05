

property _logLines : Collection
property _maxLogLines : Integer
property _attackRunning : Boolean

shared singleton Class constructor()
	
	This:C1470._logLines:=New shared collection:C1527
	This:C1470._maxLogLines:=500
	This:C1470._attackRunning:=False:C215
	
	var $config : cs:C1710.ConfigManager
	$config:=cs:C1710.ConfigManager.me
	If ($config.get("defenses.shield")=Null:C1517)
		$config.set("defenses.shield"; True:C214)
	End if 
	If ($config.get("defenses.rateLimit")=Null:C1517)
		$config.set("defenses.rateLimit"; True:C214)
	End if 
	If ($config.get("defenses.handler")=Null:C1517)
		$config.set("defenses.handler"; True:C214)
	End if 
	If ($config.get("defenses.waf")=Null:C1517)
		$config.set("defenses.waf"; True:C214)
	End if 
	
	
	
shared Function handleStatus($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	
	var $d : Object
	$d:=New object:C1471
	
	var $config : cs:C1710.ConfigManager
	$config:=cs:C1710.ConfigManager.me
	var $guard : cs:C1710.DoSGuard
	$guard:=cs:C1710.DoSGuard.me
	var $ipm : cs:C1710.IPManager
	$ipm:=cs:C1710.IPManager.me
	
	var $stats : Object
	$stats:=$guard.getPublicStats()
	
	
	$d.cpu:=$stats.realCPU
	
	$d.uptime:=$stats.uptime
	$d.timestamp:=Timestamp:C1445
	
	var $blocklist : Collection
	$blocklist:=$ipm.getBlocklist()
	$d.blacklistCount:=String:C10($blocklist.length)
	
	var $blArray : Collection
	$blArray:=New collection:C1472
	var $i : Integer
	For ($i; 0; $blocklist.length-1)
		var $entry : Object
		$entry:=New object:C1471
		$entry.ip:=$blocklist[$i].ip
		var $strikeCount : Integer
		$strikeCount:=$ipm.getStrikes($blocklist[$i].ip)
		var $permThreshold : Integer
		$permThreshold:=Num:C11($config.get("rateLimiting.permanentBlockStrikes"))
		If ($permThreshold<=0)
			$permThreshold:=5
		End if 
		$entry.score:=$strikeCount/$permThreshold
		If ($entry.score>1)
			$entry.score:=1
		End if 
		If ($blocklist[$i].status="permanent")
			$entry.ttlRemaining:=999999
		Else 
			$entry.ttlRemaining:=This:C1470._parseTimeRemaining($blocklist[$i].timeRemaining)
		End if 
		$blArray.push($entry)
	End for 
	$d.blacklist:=$blArray
	
	$d.blitz:=Bool:C1537($config.get("defenses.shield"))
	$d.rateLimit:=Bool:C1537($config.get("defenses.rateLimit"))
	$d.handler:=Bool:C1537($config.get("defenses.handler"))
	$d.waf:=Bool:C1537($config.get("defenses.waf"))
	
	var $masterCfg : Variant
	$masterCfg:=$config.get("defenses.master")
	If ($masterCfg=Null:C1517)
		$d.master:=True:C214
	Else 
		$d.master:=Bool:C1537($masterCfg)
	End if 
	
	// Shield (Blitz) policy => "IP Interceptor" card on the dashboard.
	
	var $windowSec : Integer
	$windowSec:=Num:C11($config.get("rateLimiting.windowSeconds"))
	If ($windowSec<=0)
		$windowSec:=60
	End if 
	$d.blitzPolicy:=New object:C1471
	$d.blitzPolicy.rateCap:=Num:C11($config.get("rateLimiting.maxRequests"))
	$d.blitzPolicy.windowSec:=$windowSec
	$d.blitzPolicy.strikeCap:=Num:C11($config.get("rateLimiting.permanentBlockStrikes"))
	$d.blitzPolicy.blockTTL:=Num:C11($config.get("rateLimiting.blockDurationSeconds"))
	
	
	$d.rlPolicy:=New object:C1471
	$d.rlPolicy.burstSize:=Num:C11($config.get("rateLimiting.burstThreshold"))
	$d.rlPolicy.burstWindowSec:=Num:C11($config.get("rateLimiting.burstWindowSeconds"))
	$d.rlPolicy.sustainedRate:=Num:C11($config.get("rateLimiting.maxRequests"))/$windowSec
	$d.rlPolicy.cpuPanicTrigger:=Num:C11($config.get("monitoring.cpuPanicTriggerAbove"))
	
	$d.wafPolicy:=New object:C1471
	$d.wafPolicy.maxDecodePasses:=Num:C11($config.get("waf.maxDecodePasses"))
	$d.wafPolicy.maxPathDepth:=Num:C11($config.get("waf.maxPathDepth"))
	$d.wafPolicy.strictASCII:=Bool:C1537($config.get("waf.strictASCII"))
	var $rp : Collection
	$rp:=$config.get("waf.reconPatterns")
	If ($rp=Null:C1517)
		$d.wafPolicy.reconCount:=0
	Else 
		$d.wafPolicy.reconCount:=$rp.length
	End if 
	
	$d.totalRequests:=$stats.totalRequests
	$d.allowedRequests:=$stats.allowedRequests
	$d.blockedRequests:=$stats.blockedRequests
	$d.rateLimitedRequests:=$stats.rateLimitedRequests
	$d.wafRejections:=$stats.wafRejections
	$d.currentRate:=$stats.currentRate
	$d.averageRate:=$stats.averageRate
	
	$d.panicRejections:=$stats.panicRejections
	
	$d.honeypotHits:=cs:C1710.Honeypot.me.getStats().totalHits
	$d.panicState:=$guard.getPanicState()
	$d.cpuSample:=$guard.getCPUSample()
	$d.alertSummary:=cs:C1710.AlertManager.me.getSummary()
	$d.honeypotStats:=cs:C1710.Honeypot.me.getStats()
	
	return This:C1470._json($d)
	
shared Function handleLogs($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	
	var $recent : Collection
	$recent:=cs:C1710.RequestLogger.me.getRecent(50)
	
	var $lines : Collection
	$lines:=New collection:C1472
	var $i : Integer
	For ($i; 0; $recent.length-1)
		var $e : Object
		$e:=$recent[$i]
		var $line : Text
		$line:="["+$e.timestamp+"] "
		
		If (OB Is defined:C1231($e; "clientType") && (String:C10($e.clientType)#""))
			$line:=$line+"["+String:C10($e.clientType)+"] "
		End if 
		
		Case of 
			: ($e.eventType="BLOCKED") | ($e.eventType="BLOCKED_UPLOAD")
				$line:=$line+"SHIELD INTERCEPTED "+$e.ip+" → "+$e.verb+" "+$e.url+" ("+$e.detail+")"
			: ($e.eventType="RATE_LIMITED")
				$line:=$line+"Rate-Limit 429 "+$e.ip+" → "+$e.verb+" "+$e.url+" ("+$e.detail+")"
			: ($e.eventType="INVALID") | ($e.eventType="INVALID_UPLOAD") | ($e.eventType="OVERSIZED_UPLOAD")
				$line:=$line+"DEFENSE REJECTED "+$e.ip+" → "+$e.verb+" "+$e.url+" ("+$e.detail+")"
			: ($e.eventType="MALFORMED_URL") | ($e.eventType="TRAVERSAL")
				$line:=$line+"WAF REJECTED "+$e.ip+" → "+$e.verb+" "+$e.url+" ("+$e.detail+")"
			: ($e.eventType="RECON_PROBE")
				$line:=$line+"WAF RECON "+$e.ip+" → "+$e.verb+" "+$e.url+" ("+$e.detail+")"
			: ($e.eventType="ALLOWED")
				$line:=$line+"Handler: "+$e.ip+" → "+$e.verb+" "+$e.url+" "+String:C10($e.statusCode)
			: ($e.eventType="UPLOAD_OK")
				$line:=$line+"Handler: UPLOAD "+$e.ip+" → "+$e.url+" ("+$e.detail+")"
			Else 
				$line:=$line+$e.eventType+" "+$e.ip+" "+$e.verb+" "+$e.url
		End case 
		
		$lines.push($line)
	End for 
	
	
	var $injected : Collection
	$injected:=This:C1470._logLines.copy()
	For ($i; 0; $injected.length-1)
		$lines.push(String:C10($injected[$i]))
	End for 
	
	return This:C1470._json(New object:C1471("lines"; $lines))
	
	
Function _isMasterEngaged() : Boolean
	var $masterCfg : Variant
	$masterCfg:=cs:C1710.ConfigManager.me.get("defenses.master")
	If ($masterCfg=Null:C1517)
		return True:C214
	End if 
	return Bool:C1537($masterCfg)
	
	
Function _masterOffRejection() : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	$resp.setBody(JSON Stringify:C1217(New object:C1471(\
		"success"; False:C215; \
		"error"; "MASTER_SWITCH_OFF"; \
		"message"; "Master Switch is OFF — re-engage the Master Switch before managing individual defense layers.")))
	$resp.setHeader("Content-Type"; "application/json")
	$resp.setHeader("Cache-Control"; "no-store")
	$resp.setStatus(409)
	return $resp
	
	
shared Function handleToggleBlitz($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	If (Not:C34(This:C1470._isMasterEngaged()))
		return This:C1470._masterOffRejection()
	End if 
	var $enabled : Boolean
	$enabled:=This:C1470._parseEnabled($req)
	cs:C1710.ConfigManager.me.set("defenses.shield"; $enabled)
	This:C1470._injectLog("[ADMIN] Shield Interceptor (Blitz) "+Choose:C955($enabled; "ENGAGED"; "DISENGAGED"))
	return This:C1470._json(New object:C1471("enabled"; $enabled))
	
	
	
shared Function handleToggleRateLimit($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	If (Not:C34(This:C1470._isMasterEngaged()))
		return This:C1470._masterOffRejection()
	End if 
	var $enabled : Boolean
	$enabled:=This:C1470._parseEnabled($req)
	cs:C1710.ConfigManager.me.set("defenses.rateLimit"; $enabled)
	This:C1470._injectLog("[ADMIN] Rate-Limit Shield "+Choose:C955($enabled; "ENGAGED"; "DISENGAGED"))
	return This:C1470._json(New object:C1471("enabled"; $enabled))
	
	
	
shared Function handleToggleHandler($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	If (Not:C34(This:C1470._isMasterEngaged()))
		return This:C1470._masterOffRejection()
	End if 
	var $enabled : Boolean
	$enabled:=This:C1470._parseEnabled($req)
	cs:C1710.ConfigManager.me.set("defenses.handler"; $enabled)
	This:C1470._injectLog("[ADMIN] Handler Defense "+Choose:C955($enabled; "ENGAGED"; "DISENGAGED"))
	return This:C1470._json(New object:C1471("enabled"; $enabled))
	
	
	
shared Function handleToggleWAF($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	If (Not:C34(This:C1470._isMasterEngaged()))
		return This:C1470._masterOffRejection()
	End if 
	var $enabled : Boolean
	$enabled:=This:C1470._parseEnabled($req)
	cs:C1710.ConfigManager.me.set("defenses.waf"; $enabled)
	This:C1470._injectLog("[ADMIN] WAF Inspector "+Choose:C955($enabled; "ENGAGED"; "DISENGAGED"))
	return This:C1470._json(New object:C1471("enabled"; $enabled))
	
	
shared Function handleToggleMaster($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $enabled : Boolean
	$enabled:=This:C1470._parseEnabled($req)
	cs:C1710.ConfigManager.me.set("defenses.master"; $enabled)
	
	var $ip : Text
	$ip:=cs:C1710.DoSGuard.me._extractIP($req)
	var $stateText : Text
	$stateText:=Choose:C955($enabled; "ENGAGED — defenses ON"; "DISENGAGED — UNMITIGATED traffic")
	This:C1470._injectLog("[ADMIN] Global Defense Master "+$stateText)
	cs:C1710.RequestLogger.me.log("ADMIN"; $ip; "POST"; "/admin/toggle/master"; 200; \
		"Master switch "+$stateText)
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[MASTER] Defense master "+$stateText+" by "+$ip; \
		Information message:K38:1)
	
	
	If (Not:C34($enabled))
		cs:C1710.AlertManager.me.raise("WARNING"; "MASTER_OFF"; "Defense master DISENGAGED"; \
			"Every defense layer is bypassed by "+$ip+". The system is processing unmitigated traffic until the master switch is re-engaged."; \
			New object:C1471("by"; $ip))
	End if 
	
	return This:C1470._json(New object:C1471(\
		"enabled"; $enabled; \
		"master"; $enabled; \
		"message"; "Master "+$stateText))
	
	
	
shared Function handleAttackDos($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	If (This:C1470._attackRunning)
		return This:C1470._error(429; "Attack already running — wait for it to complete")
	End if 
	Use (This:C1470)
		This:C1470._attackRunning:=True:C214
	End use 
	This:C1470._injectLog("[ATTACK] CPU ARMAGEDDON launched — 200 requests → /heavy")
	CALL WORKER:C1389("attack_worker"; Formula:C1597(Attack_CPUArmageddon))
	return This:C1470._json(New object:C1471("launched"; True:C214; "type"; "dos"; "message"; "CPU Armageddon attack launched"))
	
shared Function handleAttackBandwidth($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	If (This:C1470._attackRunning)
		return This:C1470._error(429; "Attack already running — wait for it to complete")
	End if 
	Use (This:C1470)
		This:C1470._attackRunning:=True:C214
	End use 
	This:C1470._injectLog("[ATTACK] BANDWIDTH OVERCHARGE launched — multi-pass traffic including recon & traversal")
	CALL WORKER:C1389("attack_worker"; Formula:C1597(Attack_Bandwidth))
	return This:C1470._json(New object:C1471("launched"; True:C214; "type"; "bandwidth"; "message"; "Bandwidth Overcharge attack launched"))
	
shared Function handleReport($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	
	var $stats; $ipStatus; $alertSummary; $logStats; $config : Object
	$stats:=cs:C1710.DoSGuard.me.getPublicStats()
	$ipStatus:=cs:C1710.IPManager.me.getStatus()
	$alertSummary:=cs:C1710.AlertManager.me.getSummary()
	$logStats:=cs:C1710.RequestLogger.me.getStats()
	$config:=cs:C1710.ConfigManager.me.getAll()
	
	var $html : Text
	$html:="<!DOCTYPE html><html><head><meta charset='UTF-8'>"
	$html:=$html+"<title>Sentinel Report — "+Timestamp:C1445+"</title>"
	$html:=$html+"<style>body{font-family:monospace;background:#0a0e1a;color:#dde4ed;padding:40px;max-width:900px;margin:0 auto}"
	$html:=$html+"h1{font-size:24px;letter-spacing:0.15em;text-transform:uppercase;border-bottom:1px solid #1c2128;padding-bottom:16px}"
	$html:=$html+"h2{font-size:14px;letter-spacing:0.12em;text-transform:uppercase;color:#7a8a9a;margin-top:32px}"
	$html:=$html+"table{width:100%;border-collapse:collapse;margin:12px 0}"
	$html:=$html+"td,th{text-align:left;padding:8px 12px;border-bottom:1px solid #1c2128;font-size:13px}"
	$html:=$html+"th{color:#3d4f60;font-size:10px;letter-spacing:0.15em;text-transform:uppercase}"
	$html:=$html+".val{color:#1d6feb}.red{color:#da3633}.green{color:#2ea043}.amber{color:#d29922}"
	$html:=$html+"</style></head><body>"
	$html:=$html+"<h1>⬡ Sentinel — Status Report</h1>"
	$html:=$html+"<p style='color:#3d4f60;font-size:11px'>Generated: "+Timestamp:C1445+"</p>"
	
	$html:=$html+"<h2>Guard Statistics</h2><table>"
	$html:=$html+"<tr><td>Total Requests</td><td class='val'>"+String:C10($stats.totalRequests)+"</td></tr>"
	$html:=$html+"<tr><td>Allowed</td><td class='green'>"+String:C10($stats.allowedRequests)+"</td></tr>"
	$html:=$html+"<tr><td>Blocked</td><td class='red'>"+String:C10($stats.blockedRequests)+"</td></tr>"
	$html:=$html+"<tr><td>Rate Limited</td><td class='amber'>"+String:C10($stats.rateLimitedRequests)+"</td></tr>"
	$html:=$html+"<tr><td>Invalid</td><td class='red'>"+String:C10($stats.invalidRequests)+"</td></tr>"
	$html:=$html+"<tr><td>WAF Rejections</td><td class='red'>"+String:C10($stats.wafRejections)+"</td></tr>"
	$html:=$html+"<tr><td>Uptime</td><td class='val'>"+String:C10($stats.uptime)+"s</td></tr>"
	$html:=$html+"<tr><td>Current Rate</td><td class='val'>"+String:C10($stats.currentRate)+" req/min</td></tr>"
	$html:=$html+"</table>"
	
	$html:=$html+"<h2>IP Status</h2><table>"
	$html:=$html+"<tr><td>Blocked IPs</td><td class='red'>"+String:C10($ipStatus.blockedCount)+"</td></tr>"
	$html:=$html+"<tr><td>Permanent Blocks</td><td class='red'>"+String:C10($ipStatus.permanentBlocks)+"</td></tr>"
	$html:=$html+"<tr><td>Allowlisted IPs</td><td class='green'>"+String:C10($ipStatus.allowedCount)+"</td></tr>"
	$html:=$html+"<tr><td>Total Strikes</td><td class='amber'>"+String:C10($ipStatus.totalStrikes)+"</td></tr>"
	$html:=$html+"</table>"
	
	$html:=$html+"<h2>Alert Summary</h2><table>"
	$html:=$html+"<tr><td>Total Alerts</td><td class='val'>"+String:C10($alertSummary.total)+"</td></tr>"
	$html:=$html+"<tr><td>Critical</td><td class='red'>"+String:C10($alertSummary.critical)+"</td></tr>"
	$html:=$html+"<tr><td>Warning</td><td class='amber'>"+String:C10($alertSummary.warning)+"</td></tr>"
	$html:=$html+"<tr><td>Info</td><td class='val'>"+String:C10($alertSummary.info)+"</td></tr>"
	$html:=$html+"</table>"
	
	$html:=$html+"<h2>Defense Layer Status</h2><table>"
	$html:=$html+"<tr><td>Shield Interceptor (Blitz)</td><td class='"+Choose:C955(Bool:C1537($config.defenses.shield); "green"; "red")+"'>"+Choose:C955(Bool:C1537($config.defenses.shield); "ENGAGED"; "DISENGAGED")+"</td></tr>"
	$html:=$html+"<tr><td>Rate-Limit Shield</td><td class='"+Choose:C955(Bool:C1537($config.defenses.rateLimit); "green"; "red")+"'>"+Choose:C955(Bool:C1537($config.defenses.rateLimit); "ENGAGED"; "DISENGAGED")+"</td></tr>"
	$html:=$html+"<tr><td>Handler Defense</td><td class='"+Choose:C955(Bool:C1537($config.defenses.handler); "green"; "red")+"'>"+Choose:C955(Bool:C1537($config.defenses.handler); "ENGAGED"; "DISENGAGED")+"</td></tr>"
	$html:=$html+"<tr><td>WAF Inspector</td><td class='"+Choose:C955(Bool:C1537($config.defenses.waf); "green"; "red")+"'>"+Choose:C955(Bool:C1537($config.defenses.waf); "ENGAGED"; "DISENGAGED")+"</td></tr>"
	$html:=$html+"</table>"
	
	var $bl : Collection
	$bl:=cs:C1710.IPManager.me.getBlocklist()
	$html:=$html+"<h2>Active Blocklist ("+String:C10($bl.length)+")</h2>"
	If ($bl.length>0)
		$html:=$html+"<table><tr><th>IP</th><th>Reason</th><th>Strikes</th><th>Status</th><th>Remaining</th></tr>"
		var $bi : Integer
		For ($bi; 0; $bl.length-1)
			$html:=$html+"<tr><td>"+$bl[$bi].ip+"</td><td>"+$bl[$bi].reason+"</td><td>"+String:C10($bl[$bi].strikes)+"</td><td>"+$bl[$bi].status+"</td><td>"+$bl[$bi].timeRemaining+"</td></tr>"
		End for 
		$html:=$html+"</table>"
	Else 
		$html:=$html+"<p style='color:#3d4f60'>No active entries</p>"
	End if 
	
	$html:=$html+"<h2>Rate Limiting Configuration</h2><table>"
	$html:=$html+"<tr><td>Max Requests/Window</td><td class='val'>"+String:C10(Num:C11($config.rateLimiting.maxRequests))+"</td></tr>"
	$html:=$html+"<tr><td>Window</td><td class='val'>"+String:C10(Num:C11($config.rateLimiting.windowSeconds))+"s</td></tr>"
	$html:=$html+"<tr><td>Block Duration</td><td class='val'>"+String:C10(Num:C11($config.rateLimiting.blockDurationSeconds))+"s</td></tr>"
	$html:=$html+"<tr><td>Burst Threshold</td><td class='val'>"+String:C10(Num:C11($config.rateLimiting.burstThreshold))+"</td></tr>"
	$html:=$html+"<tr><td>Burst Window</td><td class='val'>"+String:C10(Num:C11($config.rateLimiting.burstWindowSeconds))+"s</td></tr>"
	$html:=$html+"<tr><td>Permanent Block Strikes</td><td class='val'>"+String:C10(Num:C11($config.rateLimiting.permanentBlockStrikes))+"</td></tr>"
	$html:=$html+"</table>"
	
	$html:=$html+"<p style='color:#3d4f60;margin-top:40px;font-size:10px;letter-spacing:0.15em;text-transform:uppercase'>End of report — Sentinel / 4D v21.0 LTS</p>"
	$html:=$html+"</body></html>"
	
	$resp.setBody($html)
	$resp.setHeader("Content-Type"; "text/html; charset=utf-8")
	$resp.setStatus(200)
	return $resp
	
	
	
shared Function handleSnapshot($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $data : Object
	$data:=New object:C1471
	
	$data.stats:=cs:C1710.DoSGuard.me.getPublicStats()
	$data.ipStatus:=cs:C1710.IPManager.me.getStatus()
	$data.blocklist:=cs:C1710.IPManager.me.getBlocklist()
	$data.allowlist:=cs:C1710.IPManager.me.getAllowlist()
	
	$data.alertSummary:=cs:C1710.AlertManager.me.getSummary()
	$data.recentAlerts:=cs:C1710.AlertManager.me.getAlerts(Null:C1517).slice(0; 20)
	
	$data.logStats:=cs:C1710.RequestLogger.me.getStats()
	$data.topIPs:=cs:C1710.RequestLogger.me.getTopIPs(15)
	$data.hourlyStats:=cs:C1710.RequestLogger.me.getHourlyStats()
	
	$data.rateHistory:=cs:C1710.DoSGuard.me.getRateHistory()
	$data.config:=cs:C1710.ConfigManager.me.getAll()
	
	$data.uploads:=New object:C1471("count"; cs:C1710.FileUploadHandler.me.uploadCount; \
		"totalBytes"; cs:C1710.FileUploadHandler.me.totalBytes)
	
	If ($data.stats.totalRequests>0)
		$data.blockRate:=($data.stats.blockedRequests/$data.stats.totalRequests)*100
		$data.allowRate:=($data.stats.allowedRequests/$data.stats.totalRequests)*100
		$data.wafRejectionRate:=($data.stats.wafRejections/$data.stats.totalRequests)*100
	Else 
		$data.blockRate:=0
		$data.allowRate:=100
		$data.wafRejectionRate:=0
	End if 
	
	var $up : Integer
	$up:=$data.stats.uptime
	$data.uptimeFormatted:=""
	If ($up>=86400)
		$data.uptimeFormatted:=String:C10($up\86400)+"d "
	End if 
	$data.uptimeFormatted:=$data.uptimeFormatted+String:C10(($up%86400)\3600)+"h "+String:C10(($up%3600)\60)+"m"
	
	If ($data.alertSummary.critical>0)
		$data.threatLevel:="CRITICAL"
	Else 
		If ($data.alertSummary.warning>0)
			$data.threatLevel:="ELEVATED"
		Else 
			$data.threatLevel:="NORMAL"
		End if 
	End if 
	
	return This:C1470._json($data)
	
shared Function handleTraffic($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $data : Object
	$data:=New object:C1471
	$data.entries:=cs:C1710.RequestLogger.me.getRecent(200)
	$data.stats:=cs:C1710.DoSGuard.me.getPublicStats()
	return This:C1470._json($data)
	
shared Function handleBlockIP($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $params : Object
	$params:=JSON Parse:C1218($req.getText())
	If ($params=Null:C1517)
		return This:C1470._error(400; "Invalid JSON")
	End if 
	If (Not:C34(OB Is defined:C1231($params; "ip")))
		return This:C1470._error(400; "Missing 'ip'")
	End if 
	var $dur : Integer
	$dur:=300
	If (OB Is defined:C1231($params; "duration"))
		$dur:=$params.duration
	End if 
	var $reason : Text
	$reason:="Manual block via dashboard"
	If (OB Is defined:C1231($params; "reason"))
		$reason:=$params.reason
	End if 
	return This:C1470._json(cs:C1710.IPManager.me.blockIP($params.ip; $dur; $reason))
	
shared Function handleUnblockIP($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $params : Object
	$params:=JSON Parse:C1218($req.getText())
	If ($params=Null:C1517)
		return This:C1470._error(400; "Invalid JSON")
	End if 
	var $ok : Boolean
	$ok:=cs:C1710.IPManager.me.unblockIP($params.ip)
	return This:C1470._json(New object:C1471("success"; $ok; "message"; Choose:C955($ok; "Unblocked"; "Not found")))
	
shared Function handleAllowIP($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $params : Object
	$params:=JSON Parse:C1218($req.getText())
	If ($params=Null:C1517)
		return This:C1470._error(400; "Invalid JSON")
	End if 
	var $reason : Text
	$reason:="Manual allowlist"
	If (OB Is defined:C1231($params; "reason"))
		$reason:=$params.reason
	End if 
	return This:C1470._json(cs:C1710.IPManager.me.allowIP($params.ip; $reason))
	
shared Function handleRemoveAllow($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $params : Object
	$params:=JSON Parse:C1218($req.getText())
	If ($params=Null:C1517)
		return This:C1470._error(400; "Invalid JSON")
	End if 
	var $ok : Boolean
	$ok:=cs:C1710.IPManager.me.removeFromAllowlist($params.ip)
	return This:C1470._json(New object:C1471("success"; $ok))
	
shared Function handleGetConfig($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	return This:C1470._json(cs:C1710.ConfigManager.me.getAll())
	
shared Function handleSaveConfig($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $submitted : Object
	$submitted:=JSON Parse:C1218($req.getText())
	If ($submitted=Null:C1517)
		return This:C1470._error(400; "Invalid JSON")
	End if 
	
	var $cfgMgr : cs:C1710.ConfigManager
	$cfgMgr:=cs:C1710.ConfigManager.me
	var $current : Object
	$current:=$cfgMgr.getAll()
	
	If (Not:C34(OB Is defined:C1231($submitted; "auth")))
		$submitted.auth:=New object:C1471
	End if 
	$submitted.auth.dashboardPassphrase:=$current.auth.dashboardPassphrase
	$submitted.auth.dynamicPassphraseHash:=$current.auth.dynamicPassphraseHash
	$submitted.auth.dynamicPassphraseCreatedAt:=$current.auth.dynamicPassphraseCreatedAt
	$submitted.auth.dynamicPassphrasePersistent:=$current.auth.dynamicPassphrasePersistent
	$submitted.auth.sessionTimeoutMinutes:=$current.auth.sessionTimeoutMinutes
	
	If (Not:C34(OB Is defined:C1231($submitted; "server")))
		$submitted.server:=New object:C1471
	End if 
	$submitted.server.port:=$current.server.port
	
	If (Not:C34(OB Is defined:C1231($submitted; "allowlist")))
		$submitted.allowlist:=New object:C1471
	End if 
	$submitted.allowlist.ips:=$current.allowlist.ips
	
	If (OB Is defined:C1231($submitted; "honeypot") & OB Is defined:C1231($current.honeypot; "paths"))
		$submitted.honeypot.paths:=$current.honeypot.paths
	End if 
	If (OB Is defined:C1231($submitted; "waf") & OB Is defined:C1231($current.waf; "reconPatterns"))
		$submitted.waf.reconPatterns:=$current.waf.reconPatterns
	End if 
	If (OB Is defined:C1231($submitted; "security") & OB Is defined:C1231($current.security; "trustedProxies"))
		$submitted.security.trustedProxies:=$current.security.trustedProxies
	End if 
	
	
	var $v : Object
	$v:=This:C1470._validateConfigPayload($submitted)
	If (Not:C34($v.ok))
		var $resp : 4D:C1709.OutgoingMessage
		$resp:=4D:C1709.OutgoingMessage.new()
		$resp.setBody(JSON Stringify:C1217(New object:C1471("error"; "Validation failed"; "fields"; $v.errors)))
		$resp.setHeader("Content-Type"; "application/json")
		$resp.setHeader("Cache-Control"; "no-store")
		$resp.setStatus(400)
		return $resp
	End if 
	
	$cfgMgr.setAll($submitted)
	return This:C1470._json(New object:C1471("success"; True:C214; "message"; "Configuration saved"; "savedAt"; Timestamp:C1445))
	
shared Function handleResetConfig($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	cs:C1710.ConfigManager.me.resetToDefaults()
	return This:C1470._json(New object:C1471("success"; True:C214; "message"; "Configuration reset to defaults"; "config"; cs:C1710.ConfigManager.me.getAll()))
	
	
shared Function _validateConfigPayload($newConfig : Object) : Object
	var $errors : Collection
	$errors:=New collection:C1472
	
	If ($newConfig=Null:C1517)
		$errors.push(New object:C1471("path"; ""; "message"; "Missing payload"))
		return New object:C1471("ok"; False:C215; "errors"; $errors)
	End if 
	
	var $posIntPaths : Collection
	$posIntPaths:=New collection:C1472(\
		"rateLimiting.maxRequests"; \
		"rateLimiting.windowSeconds"; \
		"rateLimiting.blockDurationSeconds"; \
		"rateLimiting.burstThreshold"; \
		"rateLimiting.burstWindowSeconds"; \
		"rateLimiting.permanentBlockStrikes"; \
		"rateLimiting.globalMaxPerMinute"; \
		"validation.maxBodySizeMB"; \
		"validation.maxURLLength"; \
		"validation.maxHeaderBytes"; \
		"monitoring.cpuSampleIntervalMs"; \
		"panic.durationSeconds"; \
		"panic.autoTriggerMultiplier"; \
		"panic.samplingMultiplier"; \
		"honeypot.banDurationSec"; \
		"server.maxConcurrentRequests"; \
		"server.sessionTimeoutMinutes"; \
		"logging.maxMemoryEntries"; \
		"logging.flushIntervalSeconds"; \
		"logging.sampledLoggingThreshold"; \
		"alerts.rateLimitThreshold"; \
		"alerts.blocklistThreshold"; \
		"alerts.trafficSpikeMultiplier"; \
		"alerts.wafRejectionThreshold"; \
		"alerts.globalRateHitThreshold"; \
		"ui.refreshIntervalSeconds"; \
		"waf.maxDecodePasses"; \
		"waf.maxPathDepth")
	var $i : Integer
	For ($i; 0; $posIntPaths.length-1)
		This:C1470._checkPositiveInt($newConfig; $posIntPaths[$i]; $errors)
	End for 
	
	var $nonNegPaths : Collection
	$nonNegPaths:=New collection:C1472(\
		"monitoring.cpuPanicMinDurationSec")
	For ($i; 0; $nonNegPaths.length-1)
		This:C1470._checkNonNegInt($newConfig; $nonNegPaths[$i]; $errors)
	End for 
	
	var $percentPaths : Collection
	$percentPaths:=New collection:C1472(\
		"monitoring.cpuPanicTriggerAbove"; \
		"monitoring.cpuPanicLiftBelow"; \
		"panic.samplingRate"; \
		"logging.samplingRate")
	For ($i; 0; $percentPaths.length-1)
		This:C1470._checkPercent($newConfig; $percentPaths[$i]; $errors)
	End for 
	
	var $boolPaths : Collection
	$boolPaths:=New collection:C1472(\
		"defenses.shield"; \
		"defenses.rateLimit"; \
		"defenses.handler"; \
		"defenses.waf"; \
		"defenses.master"; \
		"defenses.honeypot"; \
		"validation.requireUserAgent"; \
		"monitoring.cpuPanicEnabled"; \
		"panic.autoTriggerEnabled"; \
		"alerts.enabled"; \
		"logging.enabled"; \
		"security.rejectUnknownURLs"; \
		"security.unknownURLStrikes"; \
		"honeypot.enabled"; \
		"waf.strictASCII")
	For ($i; 0; $boolPaths.length-1)
		This:C1470._checkBoolean($newConfig; $boolPaths[$i]; $errors)
	End for 
	
	
	var $triggerFailed : Boolean
	$triggerFailed:=False:C215
	var $liftFailed : Boolean
	$liftFailed:=False:C215
	var $e : Integer
	For ($e; 0; $errors.length-1)
		If ($errors[$e].path="monitoring.cpuPanicTriggerAbove")
			$triggerFailed:=True:C214
		End if 
		If ($errors[$e].path="monitoring.cpuPanicLiftBelow")
			$liftFailed:=True:C214
		End if 
	End for 
	If (Not:C34($triggerFailed) & Not:C34($liftFailed))
		var $trigger : Real
		$trigger:=Num:C11(This:C1470._getDottedValue($newConfig; "monitoring.cpuPanicTriggerAbove"))
		var $lift : Real
		$lift:=Num:C11(This:C1470._getDottedValue($newConfig; "monitoring.cpuPanicLiftBelow"))
		If ($lift>=$trigger)
			$errors.push(New object:C1471(\
				"path"; "monitoring.cpuPanicLiftBelow"; \
				"message"; "Lift threshold must be lower than trigger threshold ("+String:C10($trigger)+")"))
		End if 
	End if 
	
	return New object:C1471("ok"; ($errors.length=0); "errors"; $errors)
	
	
shared Function _getDottedValue($cfg : Object; $path : Text) : Variant
	If ($cfg=Null:C1517)
		return Null:C1517
	End if 
	var $parts : Collection
	$parts:=Split string:C1554($path; ".")
	var $obj : Object
	$obj:=$cfg
	var $i : Integer
	For ($i; 0; $parts.length-2)
		If (OB Is defined:C1231($obj; $parts[$i]) & ($obj[$parts[$i]]#Null:C1517))
			$obj:=$obj[$parts[$i]]
		Else 
			return Null:C1517
		End if 
	End for 
	If (OB Is defined:C1231($obj; $parts[$parts.length-1]))
		return $obj[$parts[$parts.length-1]]
	End if 
	return Null:C1517
	
	
shared Function _hasDottedPath($cfg : Object; $path : Text) : Boolean
	If ($cfg=Null:C1517)
		return False:C215
	End if 
	var $parts : Collection
	$parts:=Split string:C1554($path; ".")
	var $obj : Object
	$obj:=$cfg
	var $i : Integer
	For ($i; 0; $parts.length-2)
		If (OB Is defined:C1231($obj; $parts[$i]) & ($obj[$parts[$i]]#Null:C1517))
			$obj:=$obj[$parts[$i]]
		Else 
			return False:C215
		End if 
	End for 
	return OB Is defined:C1231($obj; $parts[$parts.length-1])
	
shared Function _checkPositiveInt($cfg : Object; $path : Text; $errors : Collection)
	If (Not:C34(This:C1470._hasDottedPath($cfg; $path)))
		$errors.push(New object:C1471("path"; $path; "message"; "Missing"))
		return 
	End if 
	var $v : Variant
	$v:=This:C1470._getDottedValue($cfg; $path)
	var $t : Integer
	$t:=Value type:C1509($v)
	If (($t#Is real:K8:4) & ($t#Is longint:K8:6))
		$errors.push(New object:C1471("path"; $path; "message"; "Must be a whole number greater than 0"))
		return 
	End if 
	var $n : Real
	$n:=Num:C11($v)
	If (($n<=0) | (Int:C8($n)#$n))
		$errors.push(New object:C1471("path"; $path; "message"; "Must be a whole number greater than 0"))
	End if 
	
shared Function _checkNonNegInt($cfg : Object; $path : Text; $errors : Collection)
	If (Not:C34(This:C1470._hasDottedPath($cfg; $path)))
		$errors.push(New object:C1471("path"; $path; "message"; "Missing"))
		return 
	End if 
	var $v : Variant
	$v:=This:C1470._getDottedValue($cfg; $path)
	var $t : Integer
	$t:=Value type:C1509($v)
	If (($t#Is real:K8:4) & ($t#Is longint:K8:6))
		$errors.push(New object:C1471("path"; $path; "message"; "Must be a whole number ≥ 0"))
		return 
	End if 
	var $n : Real
	$n:=Num:C11($v)
	If (($n<0) | (Int:C8($n)#$n))
		$errors.push(New object:C1471("path"; $path; "message"; "Must be a whole number ≥ 0"))
	End if 
	
shared Function _checkPercent($cfg : Object; $path : Text; $errors : Collection)
	If (Not:C34(This:C1470._hasDottedPath($cfg; $path)))
		$errors.push(New object:C1471("path"; $path; "message"; "Missing"))
		return 
	End if 
	var $v : Variant
	$v:=This:C1470._getDottedValue($cfg; $path)
	var $t : Integer
	$t:=Value type:C1509($v)
	If (($t#Is real:K8:4) & ($t#Is longint:K8:6))
		$errors.push(New object:C1471("path"; $path; "message"; "Must be a whole number between 1 and 100"))
		return 
	End if 
	var $n : Real
	$n:=Num:C11($v)
	If (($n<1) | ($n>100) | (Int:C8($n)#$n))
		$errors.push(New object:C1471("path"; $path; "message"; "Must be a whole number between 1 and 100"))
	End if 
	
shared Function _checkBoolean($cfg : Object; $path : Text; $errors : Collection)
	If (Not:C34(This:C1470._hasDottedPath($cfg; $path)))
		$errors.push(New object:C1471("path"; $path; "message"; "Missing"))
		return 
	End if 
	var $v : Variant
	$v:=This:C1470._getDottedValue($cfg; $path)
	If (Value type:C1509($v)#Is boolean:K8:9)
		$errors.push(New object:C1471("path"; $path; "message"; "Must be true or false"))
	End if 
	
	
	
shared Function handleExplainIP($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	
	var $ip : Text
	$ip:=""
	If (OB Is defined:C1231($req.urlQuery; "ip"))
		$ip:=String:C10($req.urlQuery.ip)
	End if 
	$ip:=Trim:C1853($ip)
	If ($ip="")
		return This:C1470._error(400; "Missing 'ip' query parameter")
	End if 
	
	var $limit : Integer
	$limit:=200
	If (OB Is defined:C1231($req.urlQuery; "limit"))
		$limit:=Num:C11($req.urlQuery.limit)
	End if 
	If ($limit<=0)
		$limit:=200
	End if 
	If ($limit>2000)
		$limit:=2000
	End if 
	
	var $ipMgr : cs:C1710.IPManager
	$ipMgr:=cs:C1710.IPManager.me
	var $config : cs:C1710.ConfigManager
	$config:=cs:C1710.ConfigManager.me
	
	var $status : Object
	$status:=New object:C1471
	$status.blocked:=$ipMgr.isBlocked($ip)
	$status.allowlisted:=$ipMgr.isAllowlisted($ip)
	$status.permanent:=False:C215
	$status.expirySec:=0
	
	var $permThreshold : Integer
	$permThreshold:=Num:C11($config.get("rateLimiting.permanentBlockStrikes"))
	If ($permThreshold<=0)
		$permThreshold:=5
	End if 
	$status.permanentThreshold:=$permThreshold
	
	var $strikesRaw : Variant
	$strikesRaw:=$ipMgr.getStrikes($ip)
	$status.strikes:=Num:C11($strikesRaw)
	
	If ($status.blocked)
		var $bl : Collection
		$bl:=$ipMgr.getBlocklist()
		var $bIdx : Integer
		For ($bIdx; 0; $bl.length-1)
			If (String:C10($bl[$bIdx].ip)=$ip)
				If (Bool:C1537($bl[$bIdx].permanent))
					$status.permanent:=True:C214
					$status.expirySec:=0
				Else 
					$status.expirySec:=This:C1470._parseTimeRemaining(String:C10($bl[$bIdx].timeRemaining))
				End if 
			End if 
		End for 
	End if 
	
	var $entries : Collection
	$entries:=cs:C1710.RequestLogger.me.search(New object:C1471("ip"; $ip))
	If ($entries.length>$limit)
		$entries:=$entries.slice($entries.length-$limit)
	End if 
	
	var $summary : Object
	$summary:=New object:C1471
	$summary.totalRequests:=$entries.length
	$summary.verbMix:=New object:C1471
	$summary.topUrls:=New collection:C1472
	$summary.firstSeen:=""
	$summary.lastSeen:=""
	$summary.topUserAgent:=""
	
	var $urlCounts : Object
	$urlCounts:=New object:C1471
	var $i : Integer
	For ($i; 0; $entries.length-1)
		var $e : Object
		$e:=$entries[$i]
		var $verb : Text
		$verb:=String:C10($e.verb)
		If ($verb="")
			$verb:="?"
		End if 
		If (Not:C34(OB Is defined:C1231($summary.verbMix; $verb)))
			$summary.verbMix[$verb]:=0
		End if 
		$summary.verbMix[$verb]:=$summary.verbMix[$verb]+1
		
		var $url : Text
		$url:=String:C10($e.url)
		If ($url#"")
			If (Not:C34(OB Is defined:C1231($urlCounts; $url)))
				$urlCounts[$url]:=0
			End if 
			$urlCounts[$url]:=$urlCounts[$url]+1
		End if 
		
		var $ts : Text
		$ts:=String:C10($e.timestamp)
		If ($ts#"")
			If (($summary.firstSeen="") | ($ts<$summary.firstSeen))
				$summary.firstSeen:=$ts
			End if 
			If (($summary.lastSeen="") | ($ts>$summary.lastSeen))
				$summary.lastSeen:=$ts
			End if 
		End if 
	End for 
	
	var $urlKeys : Collection
	$urlKeys:=OB Keys:C1719($urlCounts)
	var $urlList : Collection
	$urlList:=New collection:C1472
	For ($i; 0; $urlKeys.length-1)
		$urlList.push(New object:C1471("url"; $urlKeys[$i]; "count"; $urlCounts[$urlKeys[$i]]))
	End for 
	$urlList:=$urlList.orderBy("count desc")
	If ($urlList.length>10)
		$urlList:=$urlList.slice(0; 10)
	End if 
	$summary.topUrls:=$urlList
	
	$summary.topUserAgent:=""
	
	var $hpAll : Collection
	$hpAll:=cs:C1710.Honeypot.me.getHits(200)
	var $hpForIP : Collection
	$hpForIP:=$hpAll.filter(Formula:C1597($1.value.ip=String:C10($2)); $ip)
	
	var $sonarForIP : Collection
	$sonarForIP:=New collection:C1472
	var $sonarSnap : Collection
	$sonarSnap:=cs:C1710.Sonar.me.getQueueSnapshot()
	var $sIdx : Integer
	For ($sIdx; 0; $sonarSnap.length-1)
		If (String:C10($sonarSnap[$sIdx].ip)=$ip)
			$sonarForIP.push($sonarSnap[$sIdx])
		End if 
	End for 
	
	
	var $dataFolder : 4D:C1709.Folder
	$dataFolder:=Folder:C1567(fk data folder:K87:12)
	var $sonarFile : 4D:C1709.File
	$sonarFile:=File:C1566($dataFolder.path+"sonar_kills.jsonl")
	If ($sonarFile.exists)
		var $killsText : Text
		$killsText:=$sonarFile.getText("UTF-8")
		var $killsLines : Collection
		$killsLines:=Split string:C1554($killsText; Char:C90(10))
		var $killStart : Integer
		$killStart:=$killsLines.length-200
		If ($killStart<0)
			$killStart:=0
		End if 
		For ($i; $killStart; $killsLines.length-1)
			var $kline : Text
			$kline:=Trim:C1853(String:C10($killsLines[$i]))
			If (($kline#"") && (Substring:C12($kline; 1; 1)="{"))
				var $kparsed : Object
				$kparsed:=JSON Parse:C1218($kline)
				If (($kparsed#Null:C1517) && (String:C10($kparsed.ip)=$ip))
					$kparsed.source:="kills"
					$sonarForIP.push($kparsed)
				End if 
			End if 
		End for 
	End if 
	
	var $archFile : 4D:C1709.File
	$archFile:=File:C1566($dataFolder.path+"sonar_archive.jsonl")
	If ($archFile.exists)
		var $archText : Text
		$archText:=$archFile.getText("UTF-8")
		var $archLines : Collection
		$archLines:=Split string:C1554($archText; Char:C90(10))
		var $archStart : Integer
		$archStart:=$archLines.length-200
		If ($archStart<0)
			$archStart:=0
		End if 
		For ($i; $archStart; $archLines.length-1)
			var $aline : Text
			$aline:=Trim:C1853(String:C10($archLines[$i]))
			If (($aline#"") && (Substring:C12($aline; 1; 1)="{"))
				var $aparsed : Object
				$aparsed:=JSON Parse:C1218($aline)
				If (($aparsed#Null:C1517) && (String:C10($aparsed.ip)=$ip))
					$aparsed.source:="archive"
					$sonarForIP.push($aparsed)
				End if 
			End if 
		End for 
	End if 
	
	var $alertsAll : Collection
	$alertsAll:=cs:C1710.AlertManager.me.getAlerts(Null:C1517)
	var $alertsForIP : Collection
	$alertsForIP:=New collection:C1472
	var $aIdx : Integer
	For ($aIdx; 0; $alertsAll.length-1)
		var $alert : Object
		$alert:=$alertsAll[$aIdx]
		If ($alert.metadata#Null:C1517)
			If (OB Is defined:C1231($alert.metadata; "ip"))
				If (String:C10($alert.metadata.ip)=$ip)
					$alertsForIP.push($alert)
				End if 
			End if 
		End if 
	End for 
	
	var $timeline : Collection
	$timeline:=New collection:C1472
	var $rawRequests : Collection
	$rawRequests:=New collection:C1472
	
	For ($i; 0; $entries.length-1)
		var $en : Object
		$en:=$entries[$i]
		var $tlRow : Object
		$tlRow:=New object:C1471
		$tlRow.ts:=String:C10($en.timestamp)
		$tlRow.type:="REQUEST"
		$tlRow.icon:="req"
		$tlRow.verb:=String:C10($en.verb)
		$tlRow.url:=String:C10($en.url)
		$tlRow.status:=Num:C11($en.statusCode)
		$tlRow.detail:=String:C10($en.eventType)+" — "+String:C10($en.detail)
		Case of 
			: ($en.eventType="BLOCKED") | ($en.eventType="BLOCKED_UPLOAD")
				$tlRow.type:="BLOCK"
				$tlRow.icon:="block"
			: ($en.eventType="RATE_LIMITED") | ($en.eventType="GLOBAL_RATE_LIMIT")
				$tlRow.type:="BLOCK"
				$tlRow.icon:="block"
			: ($en.eventType="TRAVERSAL") | ($en.eventType="MALFORMED_URL") | ($en.eventType="RECON_PROBE")
				$tlRow.type:="BLOCK"
				$tlRow.icon:="block"
		End case 
		$timeline.push($tlRow)
		
		If (OB Is defined:C1231($en; "body"))
			If (Length:C16(String:C10($en.body))>0)
				$rawRequests.push(New object:C1471(\
					"ts"; String:C10($en.timestamp); \
					"verb"; String:C10($en.verb); \
					"url"; String:C10($en.url); \
					"body"; String:C10($en.body); \
					"bodyTruncated"; Bool:C1537($en.bodyTruncated)))
			End if 
		End if 
	End for 
	
	For ($i; 0; $hpForIP.length-1)
		var $hp : Object
		$hp:=$hpForIP[$i]
		$timeline.push(New object:C1471(\
			"ts"; String:C10($hp.timestamp); \
			"type"; "HONEYPOT"; \
			"icon"; "trap"; \
			"url"; String:C10($hp.url); \
			"detail"; "Honeypot ban — "+String:C10($hp.banDuration)+"s"))
	End for 
	
	For ($i; 0; $sonarForIP.length-1)
		var $sn : Object
		$sn:=$sonarForIP[$i]
		var $snTs : Text
		$snTs:=String:C10($sn.timestamp)
		If ($snTs="")
			$snTs:=String:C10($sn.ts)
		End if 
		$timeline.push(New object:C1471(\
			"ts"; $snTs; \
			"type"; "SONAR"; \
			"icon"; "radar"; \
			"url"; String:C10($sn.url); \
			"detail"; "Sonar score "+String:C10(Num:C11($sn.score))+" — "+String:C10($sn.reasons)))
	End for 
	
	For ($i; 0; $alertsForIP.length-1)
		var $al : Object
		$al:=$alertsForIP[$i]
		$timeline.push(New object:C1471(\
			"ts"; String:C10($al.timestamp); \
			"type"; "ALERT"; \
			"icon"; "alert"; \
			"detail"; "["+String:C10($al.severity)+"] "+String:C10($al.title)+" — "+String:C10($al.message)))
	End for 
	
	$timeline:=$timeline.orderBy("ts desc")
	
	$rawRequests:=$rawRequests.orderBy("ts desc")
	
	var $response : Object
	$response:=New object:C1471(\
		"ip"; $ip; \
		"status"; $status; \
		"summary"; $summary; \
		"timeline"; $timeline; \
		"rawRequests"; $rawRequests)
	
	return This:C1470._json($response)
	
	
shared Function handleAckAlert($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $params : Object
	$params:=JSON Parse:C1218($req.getText())
	If ($params=Null:C1517)
		return This:C1470._error(400; "Invalid JSON")
	End if 
	If (OB Is defined:C1231($params; "all"))
		If ($params.all)
			cs:C1710.AlertManager.me.acknowledgeAll()
			return This:C1470._json(New object:C1471("success"; True:C214; "message"; "All acknowledged"))
		End if 
	End if 
	If (OB Is defined:C1231($params; "id"))
		return This:C1470._json(New object:C1471("success"; cs:C1710.AlertManager.me.acknowledge($params.id)))
	End if 
	return This:C1470._error(400; "Need 'id' or 'all'")
	
shared Function handleClearAlerts($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	cs:C1710.AlertManager.me.clear()
	return This:C1470._json(New object:C1471("success"; True:C214; "message"; "Alerts cleared"))
	
shared Function handleAlerts($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $data : Object
	$data:=New object:C1471
	$data.summary:=cs:C1710.AlertManager.me.getSummary()
	$data.recentAlerts:=cs:C1710.AlertManager.me.getAlerts(Null:C1517).slice(0; 50)
	return This:C1470._json($data)
	
shared Function handleSearchLogs($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $filters : Object
	$filters:=JSON Parse:C1218($req.getText())
	If ($filters=Null:C1517)
		$filters:=New object:C1471
	End if 
	var $results : Collection
	$results:=cs:C1710.RequestLogger.me.search($filters)
	return This:C1470._json(New object:C1471("count"; $results.length; "entries"; $results))
	
shared Function handleExportLogs($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	$resp.setBody(cs:C1710.RequestLogger.me.exportCSV())
	$resp.setHeader("Content-Type"; "text/csv")
	$resp.setHeader("Content-Disposition"; "attachment; filename=dos_log.csv")
	$resp.setStatus(200)
	return $resp
	
shared Function handleGetRules($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	return This:C1470._json(New object:C1471("rules"; cs:C1710.RulesManager.me.getRules()))
	
shared Function handleSaveRules($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $params : Object
	$params:=JSON Parse:C1218($req.getText())
	If ($params=Null:C1517)
		return This:C1470._error(400; "Invalid JSON")
	End if 
	If (OB Is defined:C1231($params; "rules"))
		cs:C1710.RulesManager.me.replaceAll($params.rules)
		return This:C1470._json(New object:C1471("success"; True:C214; "message"; "Rules saved. Restart web server to apply."))
	End if 
	return This:C1470._error(400; "Missing 'rules'")
	
shared Function handleGetHandlers($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	return This:C1470._json(New object:C1471("handlers"; cs:C1710.HandlersManager.me.getHandlers()))
	
shared Function handleSaveHandlers($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $params : Object
	$params:=JSON Parse:C1218($req.getText())
	If ($params=Null:C1517)
		return This:C1470._error(400; "Invalid JSON")
	End if 
	If (OB Is defined:C1231($params; "handlers"))
		cs:C1710.HandlersManager.me.replaceAll($params.handlers)
		return This:C1470._json(New object:C1471("success"; True:C214; "message"; "Handlers saved. Restart web server to apply."))
	End if 
	return This:C1470._error(400; "Missing 'handlers'")
	
shared Function handleResetGuard($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	cs:C1710.DoSGuard.me.resetAll()
	cs:C1710.IPManager.me.clearBlocklist()
	cs:C1710.RequestLogger.me.clear()
	cs:C1710.AlertManager.me.clear()
	Use (This:C1470)
		This:C1470._attackRunning:=False:C215
	End use 
	return This:C1470._json(New object:C1471("success"; True:C214; "message"; "All protection state reset"))
	
	
	
shared Function handleClearIPLists($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	
	var $ip : Text
	$ip:=cs:C1710.DoSGuard.me._extractIP($req)
	
	var $result : Object
	$result:=cs:C1710.IPManager.me.clearAll()
	
	If (Bool:C1537($result.success))
		cs:C1710.RequestLogger.me.log("ADMIN"; $ip; "POST"; "/api/dashboard/iplists/clear"; 200; \
			"IP lists cleared (blocklist, allowlist, strikes)")
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[ADMIN] IP lists cleared by "+$ip; \
			Information message:K38:1)
		return This:C1470._json($result)
	End if 
	
	cs:C1710.RequestLogger.me.log("ADMIN"; $ip; "POST"; "/api/dashboard/iplists/clear"; 500; \
		"IP lists clear FAILED — disk save unsuccessful")
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[ADMIN] IP lists clear FAILED — disk save unsuccessful (requested by "+$ip+")"; \
		Error message:K38:3)
	var $errResp : 4D:C1709.OutgoingMessage
	$errResp:=4D:C1709.OutgoingMessage.new()
	$errResp.setBody(JSON Stringify:C1217($result))
	$errResp.setHeader("Content-Type"; "application/json")
	$errResp.setHeader("Cache-Control"; "no-store")
	$errResp.setStatus(500)
	return $errResp
	
	
shared Function handleWorkerStatus($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $workers : Collection
	$workers:=cs:C1710.ProcessOrchestrator.me.getWorkerStatus()
	return This:C1470._json(New object:C1471("workers"; $workers))
	
	
shared Function handleCPUDetail($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $guard : cs:C1710.DoSGuard
	$guard:=cs:C1710.DoSGuard.me
	return This:C1470._json($guard.getCPUSample())
	
	
shared Function handlePanicTrigger($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $params : Object
	$params:=JSON Parse:C1218($req.getText())
	var $duration : Integer
	$duration:=60
	var $reason : Text
	$reason:="Manual trigger via dashboard"
	If ($params#Null:C1517)
		If (OB Is defined:C1231($params; "duration"))
			$duration:=$params.duration
		End if 
		If (OB Is defined:C1231($params; "reason"))
			$reason:=$params.reason
		End if 
	End if 
	cs:C1710.DoSGuard.me.triggerPanicMode($duration; $reason)
	This:C1470._injectLog("[ADMIN] Panic mode triggered manually — duration: "+String:C10($duration)+"s")
	return This:C1470._json(New object:C1471("success"; True:C214; "message"; "Panic mode triggered"; "duration"; $duration))
	
	
shared Function handlePanicLift($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	cs:C1710.DoSGuard.me.liftPanicMode()
	This:C1470._injectLog("[ADMIN] Panic mode lifted manually")
	return This:C1470._json(New object:C1471("success"; True:C214; "message"; "Panic mode lifted"))
	
	
shared Function handlePanicStatus($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	return This:C1470._json(cs:C1710.DoSGuard.me.getPanicState())
	
	
shared Function handleHoneypotHits($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	var $hits : Collection
	$hits:=cs:C1710.Honeypot.me.getHits(50)
	return This:C1470._json(New object:C1471("hits"; $hits; "count"; $hits.length))
	
	
shared Function handleHoneypotStats($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	return This:C1470._json(cs:C1710.Honeypot.me.getStats())
	
	
shared Function handleAttackHeaderOverflow($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	If (This:C1470._attackRunning)
		return This:C1470._error(429; "Attack already running — wait for it to complete")
	End if 
	Use (This:C1470)
		This:C1470._attackRunning:=True:C214
	End use 
	This:C1470._injectLog("[ATTACK] HEADER OVERFLOW launched — multi-pass oversized header flood")
	CALL WORKER:C1389("attack_worker"; Formula:C1597(Attack_HeaderOverflow))
	return This:C1470._json(New object:C1471("launched"; True:C214; "type"; "headeroverflow"; "message"; "Header Overflow attack launched"))
	
	
shared Function handleAttackGhostFlood($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	If (This:C1470._attackRunning)
		return This:C1470._error(429; "Attack already running — wait for it to complete")
	End if 
	Use (This:C1470)
		This:C1470._attackRunning:=True:C214
	End use 
	This:C1470._injectLog("[ATTACK] GHOST FLOOD launched — 50 rotating source IPs")
	CALL WORKER:C1389("attack_worker"; Formula:C1597(Attack_GhostFlood))
	return This:C1470._json(New object:C1471("launched"; True:C214; "type"; "ghostflood"; "message"; "Ghost Flood attack launched"))
	
	
	
Function _requireAuth() : 4D:C1709.OutgoingMessage
	var $ok : Boolean
	$ok:=False:C215
	
	var $storageExists : Boolean
	$storageExists:=OB Is defined:C1231(Session:C1714.storage; "auth") & (Session:C1714.storage.auth#Null:C1517)
	
	If ($storageExists)
		var $days : Real
		$days:=Num:C11(Current date:C33-!1970-01-01!)
		var $nowSec : Real
		$nowSec:=($days*86400)+Num:C11(Current time:C178)
		var $expiry : Real
		$expiry:=Num:C11(Session:C1714.storage.auth.expiresAt)
		var $isValid : Boolean
		$isValid:=($expiry>0) & ($nowSec<=$expiry)
		
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[AUTH] _requireAuth: storage found — expiresAt="+String:C10($expiry)+", nowSec="+\
			String:C10($nowSec)+", valid="+String:C10($isValid); \
			Information message:K38:1)
		
		If ($isValid)
			$ok:=True:C214
			var $extDays : Real
			$extDays:=Num:C11(Current date:C33-!1970-01-01!)
			var $extNow : Real
			$extNow:=($extDays*86400)+Num:C11(Current time:C178)
			Use (Session:C1714.storage.auth)
				Session:C1714.storage.auth.expiresAt:=$extNow+3600
			End use 
		End if 
	Else 
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[AUTH] _requireAuth: Session.storage.auth NOT found"; \
			Information message:K38:1)
	End if 
	
	var $hasPrivilege : Boolean
	$hasPrivilege:=Session:C1714.hasPrivilege("sentinelAdmin")
	If (Not:C34($ok))
		If ($hasPrivilege)
			LOG EVENT:C667(Into system standard outputs:K38:9; \
				"[AUTH] _requireAuth: Using ORDA fallback privilege"; \
				Information message:K38:1)
		End if 
		$ok:=$hasPrivilege
	End if 
	
	If ($ok)
		return Null:C1517
	End if 
	
	If ($storageExists)
		cs:C1710.SentinelAuth.me._maybeDestructDynamic("session timeout")
	End if 
	return This:C1470._error(403; "Authentication required")
	
	
shared Function handleSonarStats($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	
	var $stats : Object
	$stats:=cs:C1710.Sonar.me.getStats()
	return This:C1470._json($stats)
	
	
shared Function handleSonarQueue($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	
	var $snapshot : Collection
	$snapshot:=cs:C1710.Sonar.me.getQueueSnapshot()
	return This:C1470._json(New object:C1471("items"; $snapshot; "count"; $snapshot.length))
	
	
shared Function handleSonarArchive($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $auth : 4D:C1709.OutgoingMessage
	$auth:=This:C1470._requireAuth()
	If ($auth#Null:C1517)
		return $auth
	End if 
	
	var $dataFolder : 4D:C1709.Folder
	$dataFolder:=Folder:C1567(fk data folder:K87:12)
	If (Not:C34($dataFolder.exists))
		$dataFolder.create()
	End if 
	var $archiveFile : 4D:C1709.File
	$archiveFile:=File:C1566($dataFolder.path+"sonar_archive.jsonl")
	If (Not:C34($archiveFile.exists))
		$archiveFile.setText(""; "UTF-8")
	End if 
	var $entries : Collection
	$entries:=New collection:C1472
	
	If ($archiveFile.exists)
		var $text : Text
		$text:=$archiveFile.getText("UTF-8")
		var $allLines : Collection
		$allLines:=Split string:C1554($text; Char:C90(10))
		
		var $startIdx : Integer
		$startIdx:=$allLines.length-200
		If ($startIdx<0)
			$startIdx:=0
		End if 
		
		var $i : Integer
		For ($i; $startIdx; $allLines.length-1)
			var $line : Text
			$line:=Trim:C1853(String:C10($allLines[$i]))
			If ($line#"")
				If (Substring:C12($line; 1; 1)="{")
					var $parsed : Object
					$parsed:=JSON Parse:C1218($line)
					If ($parsed#Null:C1517)
						$entries.push($parsed)
					End if 
				End if 
			End if 
		End for 
	End if 
	
	return This:C1470._json(New object:C1471("entries"; $entries; "count"; $entries.length))
	
	
	
shared Function serveStaticAsset($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	
	
	var $gate : Object
	$gate:=cs:C1710.DoSGuard.me._gate($req)
	If (Not:C34($gate.accept))
		If ($gate.retryAfterSec>0)
			$resp.setHeader("Retry-After"; String:C10($gate.retryAfterSec))
		End if 
		return cs:C1710.DoSGuard.me._error($resp; $gate.status; $gate.reason; "")
	End if 
	
	var $path : Text
	$path:=$req.url
	var $q : Integer
	$q:=Position:C15("?"; $path)
	If ($q>0)
		$path:=Substring:C12($path; 1; $q-1)
	End if 
	
	
	If (Position:C15(".."; $path)>0)
		cs:C1710.RequestLogger.me.log("STATIC_TRAVERSAL"; $gate.ip; "GET"; $req.url; 400; "Path traversal in static-asset path"; "")
		return cs:C1710.DoSGuard.me._error($resp; 400; "Bad Request"; "")
	End if 
	
	If ($path="/")
		$path:="/sentinel.html"
	End if 
	If ($path="/dashboard")
		$path:="/dashboard.html"
	End if 
	
	
	var $isDashboardTier : Boolean
	$isDashboardTier:=($path="/dashboard.html") | ($path="/dashboard.css") | ($path="/dashboard.js")\
		 | ($path="/sentinel.css") | ($path="/sentinel.js")\
		 | ($path="/sentinel-config.html") | ($path="/sentinel-config.css") | ($path="/sentinel-config.js")
	If ($isDashboardTier)
		var $auth : 4D:C1709.OutgoingMessage
		$auth:=This:C1470._requireAuth()
		If ($auth#Null:C1517)
			var $isHtml : Boolean
			$isHtml:=($path="/dashboard.html") | ($path="/sentinel-config.html")
			If ($isHtml)
				cs:C1710.RequestLogger.me.log("AUTH_GATE_REDIRECT"; $gate.ip; "GET"; $req.url; 302; \
					"Unauthenticated dashboard HTML — redirected to /sentinel.html"; "")
				$resp.setStatus(302)
				$resp.setHeader("Location"; "/sentinel.html?reason=expired")
				$resp.setHeader("Cache-Control"; "no-store")
				return $resp
			End if 
			cs:C1710.RequestLogger.me.log("AUTH_GATE_REJECT"; $gate.ip; "GET"; $req.url; 403; \
				"Unauthenticated dashboard asset"; "")
			return $auth
		End if 
	End if 
	
	var $dot : Integer
	$dot:=Length:C16($path)
	While (($dot>0) & (Substring:C12($path; $dot; 1)#"."))
		$dot:=$dot-1
	End while 
	var $ext : Text
	$ext:=Lowercase:C14(Substring:C12($path; $dot))
	
	var $ct : Text
	var $isText : Boolean
	$isText:=False:C215
	Case of 
		: ($ext=".html")
			$ct:="text/html; charset=utf-8"
			$isText:=True:C214
		: ($ext=".css")
			$ct:="text/css; charset=utf-8"
			$isText:=True:C214
		: ($ext=".js")
			$ct:="application/javascript; charset=utf-8"
			$isText:=True:C214
		: ($ext=".svg")
			$ct:="image/svg+xml"
			$isText:=True:C214
		: ($ext=".png")
			$ct:="image/png"
		: ($ext=".ico")
			$ct:="image/x-icon"
		: ($ext=".woff")
			$ct:="font/woff"
		: ($ext=".woff2")
			$ct:="font/woff2"
		Else 
			return cs:C1710.DoSGuard.me._error($resp; 404; "Not Found"; "")
	End case 
	
	
	var $file : 4D:C1709.File
	$file:=File:C1566("/PACKAGE/WebFolder"+$path)
	If (Not:C34($file.exists))
		return cs:C1710.DoSGuard.me._error($resp; 404; "Not Found"; "")
	End if 
	
	If ($isText)
		$resp.setBody($file.getText("UTF-8"))
	Else 
		$resp.setBody($file.getContent())
	End if 
	$resp.setHeader("Content-Type"; $ct)
	$resp.setHeader("Cache-Control"; "no-cache, must-revalidate")
	$resp.setHeader("X-Content-Type-Options"; "nosniff")
	$resp.setHeader("X-Robots-Tag"; "noindex, nofollow")
	$resp.setStatus(200)
	return $resp
	
	
Function _json($data : Object) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	$resp.setBody(JSON Stringify:C1217($data))
	$resp.setHeader("Content-Type"; "application/json")
	$resp.setHeader("Cache-Control"; "no-store")
	$resp.setStatus(200)
	return $resp
	
Function _error($code : Integer; $msg : Text) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	$resp.setBody(JSON Stringify:C1217(New object:C1471("error"; $msg)))
	$resp.setHeader("Content-Type"; "application/json")
	$resp.setHeader("Cache-Control"; "no-store")
	$resp.setStatus($code)
	return $resp
	
Function _parseEnabled($req : 4D:C1709.IncomingMessage) : Boolean
	var $val : Text
	$val:=$req.urlQuery.enabled
	If ($val="true")
		return True:C214
	Else 
		If ($val="false")
			return False:C215
		Else 
			return True:C214
		End if 
	End if 
	
Function _injectLog($message : Text)
	var $line : Text
	$line:="["+Timestamp:C1445+"] "+$message
	
	Use (This:C1470._logLines)
		This:C1470._logLines.push($line)
		If (This:C1470._logLines.length>This:C1470._maxLogLines)
			This:C1470._logLines.shift()
		End if 
	End use 
	
	cs:C1710.RequestLogger.me.log("ADMIN"; "dashboard"; "SYSTEM"; $message; 0; $message)
	LOG EVENT:C667(Into system standard outputs:K38:9; $line; Information message:K38:1)
	
Function _parseTimeRemaining($text : Text) : Real
	If ($text="Permanent")
		return 999999
	End if 
	If ($text="Expired")
		return 0
	End if 
	
	var $seconds : Real
	$seconds:=0
	
	var $hPos : Integer
	$hPos:=Position:C15("h"; $text)
	If ($hPos>0)
		$seconds:=$seconds+(Num:C11(Substring:C12($text; 1; $hPos-1))*3600)
	End if 
	
	var $mPos : Integer
	$mPos:=Position:C15("m"; $text)
	If ($mPos>0)
		var $mStart : Integer
		$mStart:=$mPos-1
		While (($mStart>0) & (Position:C15(Substring:C12($text; $mStart; 1); "0123456789")>0))
			$mStart:=$mStart-1
		End while 
		$seconds:=$seconds+(Num:C11(Substring:C12($text; $mStart+1; $mPos-$mStart-1))*60)
	End if 
	
	var $sPos : Integer
	$sPos:=Position:C15("s"; $text)
	If ($sPos>0)
		var $sStart : Integer
		$sStart:=$sPos-1
		While (($sStart>0) & (Position:C15(Substring:C12($text; $sStart; 1); "0123456789")>0))
			$sStart:=$sStart-1
		End while 
		$seconds:=$seconds+Num:C11(Substring:C12($text; $sStart+1; $sPos-$sStart-1))
	End if 
	
	return $seconds
	