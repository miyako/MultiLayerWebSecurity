
property alerts : Collection
property _idCounter : Integer
property _maxAlerts : Integer
property _cooldowns : Object
property _cooldownSeconds : Integer
property unacknowledgedCount : Integer
property _wafCounters : Object

shared singleton Class constructor()
	This:C1470.alerts:=New shared collection:C1527
	This:C1470._idCounter:=0
	This:C1470._maxAlerts:=500
	This:C1470._cooldowns:=New shared object:C1526
	This:C1470._cooldownSeconds:=60
	This:C1470.unacknowledgedCount:=0
	This:C1470._wafCounters:=New shared object:C1526
	
	
shared Function raise($severity : Text; $category : Text; $title : Text; $message : Text; $meta : Object)
	var $key : Text
	$key:=$severity+"_"+$category+"_"+$title
	
	
	var $shouldEmit : Boolean
	$shouldEmit:=False:C215
	var $newId : Integer
	$newId:=0
	
	Use (This:C1470)
		If (OB Is defined:C1231(This:C1470._cooldowns; $key))
			If ((Milliseconds:C459-This:C1470._cooldowns[$key])<(This:C1470._cooldownSeconds*1000))
				return 
			End if 
		End if 
		This:C1470._cooldowns[$key]:=Milliseconds:C459
		
		This:C1470._idCounter:=This:C1470._idCounter+1
		$newId:=This:C1470._idCounter
		
		var $alertTemp : Object
		$alertTemp:=New object:C1471("id"; $newId; \
			"timestamp"; Timestamp:C1445; \
			"severity"; $severity; \
			"category"; $category; \
			"title"; $title; \
			"message"; $message; \
			"acknowledged"; False:C215; \
			"metadata"; $meta)
		var $alert : Object
		$alert:=OB Copy:C1225($alertTemp; ck shared:K85:29; This:C1470)
		
		This:C1470.alerts.push($alert)
		If (This:C1470.alerts.length>This:C1470._maxAlerts)
			var $removed : Object
			$removed:=This:C1470.alerts.shift()
			If (Not:C34($removed.acknowledged))
				This:C1470.unacknowledgedCount:=This:C1470.unacknowledgedCount-1
			End if 
		End if 
		
		This:C1470.unacknowledgedCount:=This:C1470.unacknowledgedCount+1
		$shouldEmit:=True:C214
	End use 
	
	If ($shouldEmit)
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[ALERT]["+$severity+"]["+$category+"] "+$title+": "+$message; \
			Information message:K38:1)
	End if 
	
	
shared Function acknowledge($alertId : Integer) : Boolean
	Use (This:C1470.alerts)
		var $i : Integer
		For ($i; 0; This:C1470.alerts.length-1)
			If (This:C1470.alerts[$i].id=$alertId)
				If (Not:C34(This:C1470.alerts[$i].acknowledged))
					This:C1470.alerts[$i].acknowledged:=True:C214
					This:C1470.unacknowledgedCount:=This:C1470.unacknowledgedCount-1
				End if 
				return True:C214
			End if 
		End for 
	End use 
	return False:C215
	
	
shared Function acknowledgeAll()
	Use (This:C1470.alerts)
		var $i : Integer
		For ($i; 0; This:C1470.alerts.length-1)
			This:C1470.alerts[$i].acknowledged:=True:C214
		End for 
	End use 
	This:C1470.unacknowledgedCount:=0
	
	
shared Function getAlerts($filter : Object) : Collection
	var $results : Collection
	$results:=This:C1470.alerts.copy()
	
	If ($filter#Null:C1517)
		If (OB Is defined:C1231($filter; "severity"))
			If ($filter.severity#"ALL")
				$results:=$results.filter(Formula:C1597($1.value.severity=String:C10($2)); $filter.severity)
			End if 
		End if 
		If (OB Is defined:C1231($filter; "unacknowledgedOnly"))
			If ($filter.unacknowledgedOnly)
				$results:=$results.filter(Formula:C1597($1.value.acknowledged=False:C215))
			End if 
		End if 
	End if 
	
	return $results.reverse()
	
	
shared Function getSummary() : Object
	var $s : Object
	$s:=New object:C1471("total"; This:C1470.alerts.length; \
		"unacknowledged"; This:C1470.unacknowledgedCount; \
		"critical"; 0; \
		"warning"; 0; \
		"info"; 0)
	
	var $i : Integer
	For ($i; 0; This:C1470.alerts.length-1)
		Case of 
			: (This:C1470.alerts[$i].severity="CRITICAL")
				$s.critical:=$s.critical+1
			: (This:C1470.alerts[$i].severity="WARNING")
				$s.warning:=$s.warning+1
			: (This:C1470.alerts[$i].severity="INFO")
				$s.info:=$s.info+1
		End case 
	End for 
	return $s
	
	
shared Function clear()
	Use (This:C1470)
		This:C1470.alerts:=New shared collection:C1527
		This:C1470._wafCounters:=New shared object:C1526
	End use 
	This:C1470.unacknowledgedCount:=0
	
	
shared Function resetWAFCounters($ip : Text)
	If ($ip="")
		Use (This:C1470)
			This:C1470._wafCounters:=New shared object:C1526
		End use 
		return 
	End if 
	If (OB Is defined:C1231(This:C1470._wafCounters; $ip))
		Use (This:C1470._wafCounters)
			OB REMOVE:C1226(This:C1470._wafCounters; $ip)
		End use 
	End if 
	
	
	
shared Function checkBurstAlert($ip : Text; $count : Integer; $window : Integer)
	This:C1470.raise("CRITICAL"; "BURST"; "Burst attack detected"; \
		"IP "+$ip+": "+String:C10($count)+" requests in "+String:C10($window)+"s — blocked"; \
		New object:C1471("ip"; $ip; "burstCount"; $count; "window"; $window))
	
	
shared Function checkRateLimitAlert($ip : Text; $count : Integer; $limit : Integer)
	var $threshold : Integer
	$threshold:=Num:C11(cs:C1710.ConfigManager.me.get("alerts.rateLimitThreshold"))
	If ($threshold<=0)
		$threshold:=50
	End if 
	If ($count>=$threshold)
		This:C1470.raise("WARNING"; "RATE_LIMIT"; "Rate limit exceeded"; \
			"IP "+$ip+" hit rate limit "+String:C10($count)+" times"; \
			New object:C1471("ip"; $ip; "count"; $count))
	End if 
	
	
shared Function checkBlocklistAlert($blockedCount : Integer)
	var $threshold : Integer
	$threshold:=Num:C11(cs:C1710.ConfigManager.me.get("alerts.blocklistThreshold"))
	If ($threshold<=0)
		$threshold:=20
	End if 
	If ($blockedCount>=$threshold)
		This:C1470.raise("CRITICAL"; "BLOCKLIST"; "Blocklist threshold"; \
			String:C10($blockedCount)+" IPs blocked — possible coordinated attack"; \
			New object:C1471("blockedCount"; $blockedCount))
	End if 
	
	
shared Function checkTrafficSpike($currentRate : Real; $avgRate : Real)
	var $mult : Real
	$mult:=Num:C11(cs:C1710.ConfigManager.me.get("alerts.trafficSpikeMultiplier"))
	If ($mult<=0)
		$mult:=3
	End if 
	If (($avgRate>0) & ($currentRate>=($avgRate*$mult)))
		This:C1470.raise("WARNING"; "TRAFFIC"; "Traffic spike"; \
			"Current "+String:C10($currentRate; "###0")+" req/min vs avg "+String:C10($avgRate; "###0")+" req/min"; \
			New object:C1471("current"; $currentRate; "average"; $avgRate))
	End if 
	
	
shared Function checkWAFRejection($ip : Text; $category : Text; $reason : Text)
	
	var $threshold : Integer
	$threshold:=Num:C11(cs:C1710.ConfigManager.me.get("alerts.wafRejectionThreshold"))
	If ($threshold<=0)
		$threshold:=10
	End if 
	
	var $shouldRaise : Boolean
	$shouldRaise:=False:C215
	var $hitCount : Integer
	$hitCount:=0
	
	Use (This:C1470._wafCounters)
		If (Not:C34(OB Is defined:C1231(This:C1470._wafCounters; $ip)))
			This:C1470._wafCounters[$ip]:=0
		End if 
		This:C1470._wafCounters[$ip]:=This:C1470._wafCounters[$ip]+1
		If (This:C1470._wafCounters[$ip]>=$threshold)
			$hitCount:=This:C1470._wafCounters[$ip]
			$shouldRaise:=True:C214
			This:C1470._wafCounters[$ip]:=0
		End if 
	End use 
	
	If ($shouldRaise)
		This:C1470.raise("WARNING"; "WAF"; "Repeated WAF rejections"; \
			"IP "+$ip+" triggered "+String:C10($hitCount)+" WAF rejections ("+$category+")"; \
			New object:C1471("ip"; $ip; "category"; $category; "reason"; $reason))
	End if 
	
	
shared Function checkReconProbe($ip : Text; $url : Text; $pattern : Text)
	This:C1470.raise("CRITICAL"; "RECON"; "Recon probe blocked"; \
		"IP "+$ip+" probed "+$pattern+" (URL: "+$url+")"; \
		New object:C1471("ip"; $ip; "url"; $url; "pattern"; $pattern))
	
	
shared Function checkGlobalRateLimit($count : Integer; $limit : Integer)
	This:C1470.raise("CRITICAL"; "GLOBAL_RATE"; "Aggregate rate limit exceeded"; \
		"Global traffic "+String:C10($count)+" req/min exceeded cap "+String:C10($limit)+\
		" — possible distributed attack"; \
		New object:C1471("count"; $count; "limit"; $limit))