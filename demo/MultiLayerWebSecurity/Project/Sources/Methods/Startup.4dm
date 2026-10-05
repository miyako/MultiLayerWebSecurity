//%attributes = {}


var $config : cs:C1710.ConfigManager
var $ipMgr : cs:C1710.IPManager
var $logger : cs:C1710.RequestLogger
var $alerts : cs:C1710.AlertManager
var $rules : cs:C1710.RulesManager
var $handlers : cs:C1710.HandlersManager
var $headerVal : cs:C1710.HeaderValidator
var $auth : cs:C1710.SentinelAuth
var $guard : cs:C1710.DoSGuard
var $upload : cs:C1710.FileUploadHandler
var $honeypot : cs:C1710.Honeypot
var $sentinel : cs:C1710.Sentinel
var $orch : cs:C1710.ProcessOrchestrator

var $webServer : Object
var $settings : Object
var $result : Object

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[STARTUP] Sentinel boot sequence initiated (Phase 3)"; \
Information message:K38:1)


$config:=cs:C1710.ConfigManager.me

$ipMgr:=cs:C1710.IPManager.me
$ipMgr.clearExpired()

$logger:=cs:C1710.RequestLogger.me
$alerts:=cs:C1710.AlertManager.me
$rules:=cs:C1710.RulesManager.me
$handlers:=cs:C1710.HandlersManager.me
$headerVal:=cs:C1710.HeaderValidator.me
$auth:=cs:C1710.SentinelAuth.me
$guard:=cs:C1710.DoSGuard.me
$upload:=cs:C1710.FileUploadHandler.me
$honeypot:=cs:C1710.Honeypot.me
$sentinel:=cs:C1710.Sentinel.me

var $sonar : cs:C1710.Sonar
$sonar:=cs:C1710.Sonar.me

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[STARTUP] Singletons initialized (HeaderValidator + SentinelAuth + Honeypot + Sonar online)"; \
Information message:K38:1)


var $rolesErrorFile : 4D:C1709.File
$rolesErrorFile:=File:C1566("/LOGS/Roles_Errors.json")
If ($rolesErrorFile.exists)
	$alerts.raise("CRITICAL"; "SYSTEM"; "roles.json parse error"; \
		"Access protection is DISABLED — fix /Project/Sources/roles.json and restart"; \
		New object:C1471("logFile"; "/LOGS/Roles_Errors.json"))
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[STARTUP] CRITICAL — Roles_Errors.json found. Access protection disabled. Fix roles.json immediately."; \
		Error message:K38:3)
End if 


var $storedPassphrase : Text
$storedPassphrase:=String:C10($config.get("auth.dashboardPassphrase"))
If ($storedPassphrase="passphrase") | ($storedPassphrase="")
	$alerts.raise("CRITICAL"; "AUTH"; "Default passphrase in use"; \
		"auth.dashboardPassphrase is set to the default value. Change it immediately via /api/dashboard/config."; \
		New object:C1471)
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[STARTUP] WARNING — Default dashboard passphrase detected. Change auth.dashboardPassphrase in config."; \
		Error message:K38:3)
End if 

$orch:=cs:C1710.ProcessOrchestrator.me
$orch.initialize()


var $sonarDataFolder : 4D:C1709.Folder
$sonarDataFolder:=Folder:C1567(fk data folder:K87:12)
If (Not:C34($sonarDataFolder.exists))
	$sonarDataFolder.create()
End if 
var $sonarArchive : 4D:C1709.File
$sonarArchive:=File:C1566($sonarDataFolder.path+"sonar_archive.jsonl")
If (Not:C34($sonarArchive.exists))
	$sonarArchive.setText(""; "UTF-8")
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[STARTUP] Initialized empty "+$sonarArchive.path; \
		Information message:K38:1)
End if 
var $sonarKills : 4D:C1709.File
$sonarKills:=File:C1566($sonarDataFolder.path+"sonar_kills.jsonl")
If (Not:C34($sonarKills.exists))
	$sonarKills.setText(""; "UTF-8")
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[STARTUP] Initialized empty "+$sonarKills.path; \
		Information message:K38:1)
End if 

$orch.spawn("cpu_monitor"; "CPUMonitor_Worker")
$orch.spawn("panic_watchdog"; "PanicWatchdog_Worker")
$orch.spawn("log_flusher"; "LogFlusher_Worker")
$orch.spawn("honeypot_sweeper"; "HoneypotSweeper_Worker")
$orch.spawn("sonar_sniper"; "Sonar_Sniper_Worker")
$orch.spawn("sonar_drone"; "Sonar_Drone_Worker")

LOG EVENT:C667(Into system standard outputs:K38:9; \
"[STARTUP] Worker mesh online — CPU monitor, panic watchdog, log flusher, honeypot sweeper, Sonar sniper, Sonar drone"; \
Information message:K38:1)

$webServer:=WEB Server:C1674
$settings:=New object:C1471
$settings.HTTPPort:=Num:C11($config.get("server.port"))
If ($settings.HTTPPort<=0)
	$settings.HTTPPort:=8044
End if 

$result:=$webServer.start($settings)

If ($result.success)
	var $port : Integer
	$port:=$webServer.HTTPPort
	
	$alerts.raise("INFO"; "SYSTEM"; "Sentinel online"; \
		"All defense layers + worker mesh (Phase 3) operational on port "+String:C10($port); \
		New object:C1471("port"; $port; "workers"; $orch.getWorkerStatus().length))
	
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[STARTUP] Sentinel ready — http://127.0.0.1:"+String:C10($port)+"/sentinel.html"; \
		Information message:K38:1)
Else 
	$alerts.raise("CRITICAL"; "SYSTEM"; "Startup failed"; \
		"Web server could not start"; \
		New object:C1471)
	
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[STARTUP] FATAL — web server failed to start"; \
		Error message:K38:3)
End if 
