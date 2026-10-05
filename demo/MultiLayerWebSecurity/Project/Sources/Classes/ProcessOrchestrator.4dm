

property _workers : Object
property _shutdownSignal : 4D:C1709.Signal
property _bootTime : Integer
property _initialized : Boolean

shared singleton Class constructor()
	This:C1470._workers:=New shared object:C1526
	This:C1470._shutdownSignal:=Null:C1517
	This:C1470._bootTime:=Milliseconds:C459
	This:C1470._initialized:=False:C215
	
	
	
shared Function initialize()
	If (This:C1470._initialized)
		return 
	End if 
	
	Use (This:C1470)
		This:C1470._shutdownSignal:=New signal:C1641("sentinel.shutdown")
		This:C1470._initialized:=True:C214
	End use 
	
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[ORCHESTRATOR] Initialized at boot"; \
		Information message:K38:1)
	
	
shared Function spawn($workerName : Text; $methodName : Text) : Boolean
	
	If (Not:C34(This:C1470._initialized))
		This:C1470.initialize()
	End if 
	
	If (This:C1470._isWorkerAlive($workerName))
		return False:C215
	End if 
	
	
	var $expectedSec : Integer
	Case of 
		: ($methodName="HoneypotSweeper_Worker")
			$expectedSec:=60
		: ($methodName="LogFlusher_Worker")
			$expectedSec:=2
		: ($methodName="Sonar_Sniper_Worker")
			$expectedSec:=1
		: ($methodName="Sonar_Drone_Worker")
			$expectedSec:=2
		Else 
			$expectedSec:=2
	End case 
	
	This:C1470._registerWorker($workerName; $methodName; $expectedSec)
	
	Case of 
		: ($methodName="CPUMonitor_Worker")
			CALL WORKER:C1389($workerName; Formula:C1597(CPUMonitor_Worker))
		: ($methodName="HoneypotSweeper_Worker")
			CALL WORKER:C1389($workerName; Formula:C1597(HoneypotSweeper_Worker))
		: ($methodName="PanicWatchdog_Worker")
			CALL WORKER:C1389($workerName; Formula:C1597(PanicWatchdog_Worker))
		: ($methodName="LogFlusher_Worker")
			CALL WORKER:C1389($workerName; Formula:C1597(LogFlusher_Worker))
		: ($methodName="Sonar_Sniper_Worker")
			CALL WORKER:C1389($workerName; Formula:C1597(Sonar_Sniper_Worker))
		: ($methodName="Sonar_Drone_Worker")
			CALL WORKER:C1389($workerName; Formula:C1597(Sonar_Drone_Worker))
		Else 
			LOG EVENT:C667(Into system standard outputs:K38:9; \
				"[ORCHESTRATOR] Unknown worker: "+$methodName; \
				Error message:K38:3)
			This:C1470._unregisterWorker($workerName)
			return False:C215
	End case 
	
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[ORCHESTRATOR] Spawned "+$workerName+" → "+$methodName; \
		Information message:K38:1)
	return True:C214
	
	
shared Function shutdown()
	If (Not:C34(This:C1470._initialized))
		return 
	End if 
	
	LOG EVENT:C667(Into system standard outputs:K38:9; \
		"[ORCHESTRATOR] Shutdown requested — triggering signal"; \
		Information message:K38:1)
	
	If (This:C1470._shutdownSignal#Null:C1517)
		This:C1470._shutdownSignal.trigger()
	End if 
	
	
	DELAY PROCESS:C323(Current process:C322; 120)
	
	
	var $workerKeys : Collection
	$workerKeys:=OB Keys:C1719(This:C1470._workers)
	var $wi : Integer
	For ($wi; 0; $workerKeys.length-1)
		KILL WORKER:C1390(String:C10($workerKeys[$wi]))
		LOG EVENT:C667(Into system standard outputs:K38:9; \
			"[ORCHESTRATOR] Killed worker process: "+String:C10($workerKeys[$wi]); \
			Information message:K38:1)
	End for 
	KILL WORKER:C1390("attack_worker")
	
	Use (This:C1470)
		This:C1470._initialized:=False:C215
		This:C1470._shutdownSignal:=Null:C1517
	End use 
	
	
shared Function getShutdownSignal() : Object
	return This:C1470._shutdownSignal
	
	
	
Function shouldShutdown() : Boolean
	If (This:C1470._shutdownSignal=Null:C1517)
		return True:C214
	End if 
	return This:C1470._shutdownSignal.signaled
	
	
Function sleep($seconds : Real) : Boolean
	If (This:C1470._shutdownSignal=Null:C1517)
		return True:C214
	End if 
	return This:C1470._shutdownSignal.wait($seconds)
	
	
	
Function heartbeat($workerName : Text)
	If (Not:C34(OB Is defined:C1231(This:C1470._workers; $workerName)))
		return 
	End if 
	Use (This:C1470._workers[$workerName])
		This:C1470._workers[$workerName].lastBeat:=Milliseconds:C459
		This:C1470._workers[$workerName].beatCount:=This:C1470._workers[$workerName].beatCount+1
	End use 
	
	
Function getWorkerStatus() : Collection
	
	var $result : Collection
	$result:=New collection:C1472
	
	var $keys : Collection
	$keys:=OB Keys:C1719(This:C1470._workers)
	var $now : Integer
	$now:=Milliseconds:C459
	
	var $i : Integer
	For ($i; 0; $keys.length-1)
		var $w : Object
		$w:=This:C1470._workers[$keys[$i]]
		var $sinceBeatSec : Integer
		$sinceBeatSec:=($now-$w.lastBeat)\1000
		
		var $expected : Integer
		$expected:=Num:C11($w.expectedIntervalSec)
		If ($expected<=0)
			$expected:=5
		End if 
		var $healthyMax : Integer
		$healthyMax:=Int:C8($expected*1.5)+1
		var $slowMax : Integer
		$slowMax:=$expected*3
		If ($slowMax<15)
			$slowMax:=15
		End if 
		
		var $status : Text
		Case of 
			: ($sinceBeatSec<=$healthyMax)
				$status:="healthy"
			: ($sinceBeatSec<=$slowMax)
				$status:="slow"
			Else 
				$status:="stalled"
		End case 
		$result.push(New object:C1471(\
			"name"; $keys[$i]; \
			"method"; $w.method; \
			"status"; $status; \
			"beatCount"; $w.beatCount; \
			"lastBeatAgoSec"; $sinceBeatSec; \
			"expectedIntervalSec"; $expected; \
			"startedAt"; $w.startedAt))
	End for 
	return $result
	
	
shared Function acquire($semName : Text; $timeoutSeconds : Real) : Boolean
	var $deadline : Integer
	$deadline:=Milliseconds:C459+($timeoutSeconds*1000)
	
	While (Semaphore:C143("$"+$semName; 1))
		If (Milliseconds:C459>=$deadline)
			LOG EVENT:C667(Into system standard outputs:K38:9; \
				"[ORCHESTRATOR] Timeout acquiring "+$semName; \
				Error message:K38:3)
			return False:C215
		End if 
		DELAY PROCESS:C323(Current process:C322; 3)
	End while 
	
	return True:C214
	
	
shared Function release($semName : Text)
	CLEAR SEMAPHORE:C144("$"+$semName)
	
	
shared Function withLock($semName : Text; $timeoutSeconds : Real; $formula : 4D:C1709.Function) : Boolean
	If (Not:C34(This:C1470.acquire($semName; $timeoutSeconds)))
		return False:C215
	End if 
	$formula.call()
	This:C1470.release($semName)
	return True:C214
	
	
	
Function _registerWorker($name : Text; $method : Text; $expectedIntervalSec : Integer)
	If ($expectedIntervalSec<=0)
		$expectedIntervalSec:=2
	End if 
	Use (This:C1470._workers)
		var $tmp : Object
		$tmp:=New object:C1471(\
			"method"; $method; \
			"startedAt"; Milliseconds:C459; \
			"lastBeat"; Milliseconds:C459; \
			"beatCount"; 0; \
			"expectedIntervalSec"; $expectedIntervalSec)
		This:C1470._workers[$name]:=OB Copy:C1225($tmp; ck shared:K85:29; This:C1470._workers)
	End use 
	
	
Function _unregisterWorker($name : Text)
	Use (This:C1470._workers)
		If (OB Is defined:C1231(This:C1470._workers; $name))
			OB REMOVE:C1226(This:C1470._workers; $name)
		End if 
	End use 
	
	
Function _isWorkerAlive($name : Text) : Boolean
	If (Not:C34(OB Is defined:C1231(This:C1470._workers; $name)))
		return False:C215
	End if 
	
	var $w : Object
	$w:=This:C1470._workers[$name]
	var $expected : Integer
	$expected:=Num:C11($w.expectedIntervalSec)
	If ($expected<=0)
		$expected:=5
	End if 
	var $stallThresh : Integer
	$stallThresh:=$expected*3
	If ($stallThresh<15)
		$stallThresh:=15
	End if 
	var $since : Integer
	$since:=(Milliseconds:C459-$w.lastBeat)\1000
	return ($since<$stallThresh)
	
	
Function _aliveWorkerCount() : Integer
	var $count : Integer
	$count:=0
	var $keys : Collection
	$keys:=OB Keys:C1719(This:C1470._workers)
	var $i : Integer
	For ($i; 0; $keys.length-1)
		If (This:C1470._isWorkerAlive($keys[$i]))
			$count:=$count+1
		End if 
	End for 
	return $count