

property _path : Text
property config : Object

shared singleton Class constructor()
	This:C1470._path:=Folder:C1567(fk data folder:K87:12).path+"dosguard_config.json"
	This:C1470.config:=New shared object:C1526
	This:C1470._load()
	
	
shared Function get($key : Text) : Variant
	var $parts : Collection
	$parts:=Split string:C1554($key; ".")
	var $obj : Object
	$obj:=This:C1470.config
	
	var $i : Integer
	For ($i; 0; $parts.length-2)
		If (OB Is defined:C1231($obj; $parts[$i]))
			$obj:=$obj[$parts[$i]]
		Else 
			return Null:C1517
		End if 
	End for 
	
	If (OB Is defined:C1231($obj; $parts[$parts.length-1]))
		return $obj[$parts[$parts.length-1]]
	End if 
	return Null:C1517
	
	
shared Function set($key : Text; $value : Variant)
	var $parts : Collection
	$parts:=Split string:C1554($key; ".")
	var $obj : Object
	$obj:=This:C1470.config
	
	Use (This:C1470.config)
		var $i : Integer
		For ($i; 0; $parts.length-2)
			If (Not:C34(OB Is defined:C1231($obj; $parts[$i])))
				$obj[$parts[$i]]:=New shared object:C1526
			End if 
			$obj:=$obj[$parts[$i]]
		End for 
		$obj[$parts[$parts.length-1]]:=$value
	End use 
	
	This:C1470._save()
	
	
shared Function getAll() : Object
	return OB Copy:C1225(This:C1470.config)
	
	
shared Function setAll($newConfig : Object)
	Use (This:C1470)
		This:C1470.config:=OB Copy:C1225($newConfig; ck shared:K85:29; This:C1470)
	End use 
	This:C1470._save()
	
	
shared Function export() : Text
	return JSON Stringify:C1217(This:C1470.config; *)
	
	
shared Function resetToDefaults()
	Use (This:C1470)
		This:C1470.config:=OB Copy:C1225(This:C1470._defaults(); ck shared:K85:29; This:C1470)
	End use 
	This:C1470._save()
	
	
Function _defaults() : Object
	var $d : Object
	$d:=New object:C1471
	
	$d.rateLimiting:=New object:C1471(\
		"maxRequests"; 100; \
		"windowSeconds"; 60; \
		"blockDurationSeconds"; 300; \
		"burstThreshold"; 20; \
		"burstWindowSeconds"; 5; \
		"permanentBlockStrikes"; 5; \
		"globalMaxPerMinute"; 10000)
	
	$d.validation:=New object:C1471(\
		"maxBodySizeMB"; 10; \
		"maxURLLength"; 2048; \
		"maxHeaderBytes"; 8192; \
		"requireUserAgent"; True:C214)
	
	$d.logging:=New object:C1471(\
		"enabled"; True:C214; \
		"maxMemoryEntries"; 2000; \
		"flushIntervalSeconds"; 2; \
		"sampledLoggingThreshold"; 20000; \
		"samplingRate"; 100)
	
	$d.alerts:=New object:C1471(\
		"enabled"; True:C214; \
		"rateLimitThreshold"; 50; \
		"blocklistThreshold"; 20; \
		"trafficSpikeMultiplier"; 3; \
		"wafRejectionThreshold"; 10; \
		"globalRateHitThreshold"; 1)
	
	$d.allowlist:=New object:C1471("ips"; New collection:C1472)
	
	$d.server:=New object:C1471(\
		"port"; 8044; \
		"maxConcurrentRequests"; 100; \
		"sessionTimeoutMinutes"; 30)
	
	$d.ui:=New object:C1471("refreshIntervalSeconds"; 3; "theme"; "dark")
	
	$d.defenses:=New object:C1471
	$d.defenses.shield:=True:C214
	$d.defenses.rateLimit:=True:C214
	$d.defenses.handler:=True:C214
	$d.defenses.waf:=True:C214
	$d.defenses.honeypot:=True:C214
	
	$d.defenses.master:=True:C214
	
	$d.waf:=New object:C1471
	$d.waf.maxDecodePasses:=3
	$d.waf.maxPathDepth:=20
	$d.waf.strictASCII:=True:C214
	$d.waf.reconPatterns:=New collection:C1472(\
		"/wp-admin"; "/wp-login"; "/wordpress"; "/wp-config"; \
		"/.env"; "/.git/"; "/.aws/"; "/.ssh/"; "/.docker"; \
		"/phpmyadmin"; "/phpinfo"; "/admin.php"; "/config.php"; \
		"/xmlrpc.php"; "/cgi-bin/"; "/vendor/phpunit"; \
		"/actuator"; "/server-status"; "/server-info"; \
		"/.well-known/security.txt.bak"; "/shell.php"; "/eval-stdin"; \
		"/etc/"; "/proc/"; "/var/log/"; "/private/etc/"; "/sys/"; "/root/"; "/.bash")
	
	$d.security:=New object:C1471
	$d.security.trustedProxies:=New collection:C1472
	$d.security.rejectUnknownURLs:=False:C215
	$d.security.unknownURLStrikes:=True:C214
	
	$d.monitoring:=New object:C1471
	$d.monitoring.cpuSampleIntervalMs:=2000
	$d.monitoring.cpuPanicEnabled:=True:C214
	$d.monitoring.cpuPanicTriggerAbove:=85
	$d.monitoring.cpuPanicLiftBelow:=50
	$d.monitoring.cpuPanicMinDurationSec:=30
	
	$d.panic:=New object:C1471
	$d.panic.autoTriggerEnabled:=True:C214
	$d.panic.autoTriggerMultiplier:=3
	$d.panic.durationSeconds:=60
	$d.panic.samplingMultiplier:=2
	$d.panic.samplingRate:=100
	
	$d.honeypot:=New object:C1471
	$d.honeypot.enabled:=True:C214
	$d.honeypot.paths:=New collection:C1472(\
		"/admin.php"; "/wp-login.php"; "/.env"; "/backup.sql"; \
		"/api/v1/token"; "/api/admin/users"; "/config.bak"; \
		"/database.yml"; "/credentials.json"; "/.ssh/id_rsa"; \
		"/aws-credentials"; "/.git/config")
	$d.honeypot.banDurationSec:=86400
	$d.honeypot.alertSeverity:="CRITICAL"
	$d.auth:=New object:C1471
	$d.auth.dashboardPassphrase:="changeme"  //don't change it mannually, use the Dynamic Passphrase Generator from the login page
	$d.auth.sessionTimeoutMinutes:=60
	$d.auth.dynamicPassphraseHash:=Null:C1517
	$d.auth.dynamicPassphraseCreatedAt:=Null:C1517
	$d.auth.dynamicPassphrasePersistent:=False:C215
	
	return $d
	
	
Function _load()
	var $file : 4D:C1709.File
	$file:=File:C1566(This:C1470._path)
	
	If ($file.exists)
		var $text : Text
		$text:=$file.getText("UTF-8")
		
		If (Length:C16($text)>2)
			var $parsed : Object
			$parsed:=JSON Parse:C1218($text)
			
			If ($parsed#Null:C1517) & (OB Is defined:C1231($parsed; "rateLimiting"))
				var $defs : Object
				$defs:=This:C1470._defaults()
				
				If (Not:C34(OB Is defined:C1231($parsed; "auth")))
					$parsed.auth:=$defs.auth
				End if 
				If (Not:C34(OB Is defined:C1231($parsed.auth; "dynamicPassphraseHash")))
					$parsed.auth.dynamicPassphraseHash:=Null:C1517
				End if 
				If (Not:C34(OB Is defined:C1231($parsed.auth; "dynamicPassphraseCreatedAt")))
					$parsed.auth.dynamicPassphraseCreatedAt:=Null:C1517
				End if 
				If (Not:C34(OB Is defined:C1231($parsed.auth; "dynamicPassphrasePersistent")))
					$parsed.auth.dynamicPassphrasePersistent:=False:C215
				End if 
				If (Not:C34(OB Is defined:C1231($parsed; "waf")))
					$parsed.waf:=$defs.waf
				End if 
				If (Not:C34(OB Is defined:C1231($parsed; "security")))
					$parsed.security:=$defs.security
				End if 
				If (Not:C34(OB Is defined:C1231($parsed.defenses; "waf")))
					$parsed.defenses.waf:=True:C214
				End if 
				If (Not:C34(OB Is defined:C1231($parsed.rateLimiting; "globalMaxPerMinute")))
					$parsed.rateLimiting.globalMaxPerMinute:=10000
				End if 
				
				Use (This:C1470)
					This:C1470.config:=OB Copy:C1225($parsed; ck shared:K85:29; This:C1470)
				End use 
				return 
			End if 
		End if 
		
		$file.delete()
	End if 
	
	Use (This:C1470)
		This:C1470.config:=OB Copy:C1225(This:C1470._defaults(); ck shared:K85:29; This:C1470)
	End use 
	
	This:C1470._save()
	
	
Function _save()
	var $folder : 4D:C1709.Folder
	$folder:=File:C1566(This:C1470._path).parent
	If (Not:C34($folder.exists))
		$folder.create()
	End if 
	
	var $tmpFile : 4D:C1709.File
	$tmpFile:=File:C1566(This:C1470._path+".tmp")
	$tmpFile.setText(JSON Stringify:C1217(This:C1470.config; *); "UTF-8")
	var $finalFile : 4D:C1709.File
	$finalFile:=File:C1566(This:C1470._path)
	If ($finalFile.exists)
		$finalFile.delete()
	End if 
	$tmpFile.rename($finalFile.fullName)