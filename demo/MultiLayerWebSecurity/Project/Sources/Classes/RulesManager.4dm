

property _path : Text
property rules : Collection

shared singleton Class constructor()
	This:C1470._path:=File:C1566("/PACKAGE/Project/Sources/HTTPRules.json").path
	This:C1470.rules:=New shared collection:C1527
	This:C1470._load()
	
	
shared Function getRules() : Collection
	return This:C1470.rules.copy()
	
shared Function addRule($rule : Object) : Object
	If ($rule=Null:C1517)
		return New object:C1471("success"; False:C215; "message"; "Rule cannot be Null")
	End if 
	
	var $shared : Object
	Use (This:C1470.rules)
		$shared:=OB Copy:C1225($rule; ck shared:K85:29; This:C1470.rules)
		This:C1470.rules.push($shared)
	End use 
	This:C1470._save()
	return New object:C1471("success"; True:C214; "message"; "Rule added at index "+String:C10(This:C1470.rules.length-1))
	
	
shared Function updateRule($index : Integer; $rule : Object) : Object
	If ($rule=Null:C1517)
		return New object:C1471("success"; False:C215; "message"; "Rule cannot be Null")
	End if 
	If (($index>=0) & ($index<This:C1470.rules.length))
		var $shared : Object
		Use (This:C1470.rules)
			$shared:=OB Copy:C1225($rule; ck shared:K85:29; This:C1470.rules)
			This:C1470.rules[$index]:=$shared
		End use 
		This:C1470._save()
		return New object:C1471("success"; True:C214; "message"; "Rule "+String:C10($index)+" updated")
	End if 
	return New object:C1471("success"; False:C215; "message"; "Invalid index")
	
	
shared Function deleteRule($index : Integer) : Boolean
	If (($index>=0) & ($index<This:C1470.rules.length))
		Use (This:C1470.rules)
			This:C1470.rules.remove($index)
		End use 
		This:C1470._save()
		return True:C214
	End if 
	return False:C215
	
	
shared Function moveRule($from : Integer; $to : Integer) : Boolean
	
	If (($from>=0) & ($from<This:C1470.rules.length) & ($to>=0) & ($to<This:C1470.rules.length))
		Use (This:C1470.rules)
			var $r : Object
			$r:=This:C1470.rules[$from]
			This:C1470.rules.remove($from)
			This:C1470.rules.insert($to; $r)
		End use 
		This:C1470._save()
		return True:C214
	End if 
	return False:C215
	
	
shared Function replaceAll($newRules : Collection)
	Use (This:C1470)
		If ($newRules#Null:C1517)
			This:C1470.rules:=$newRules.copy(ck shared:K85:29; This:C1470.rules)
		Else 
			This:C1470.rules:=New shared collection:C1527
		End if 
	End use 
	This:C1470._save()
	
	
shared Function exportJSON() : Text
	return JSON Stringify:C1217(This:C1470.rules; *)
	
	
shared Function reload()
	This:C1470._load()
	
	
Function _load()
	var $file : 4D:C1709.File
	$file:=File:C1566(This:C1470._path)
	If ($file.exists)
		var $parsed : Collection
		$parsed:=JSON Parse:C1218($file.getText("UTF-8"))
		If ($parsed#Null:C1517)
			Use (This:C1470)
				This:C1470.rules:=$parsed.copy(ck shared:K85:29; This:C1470.rules)
			End use 
		End if 
	End if 
	
	
Function _save()
	File:C1566(This:C1470._path).setText(JSON Stringify:C1217(This:C1470.rules; *); "UTF-8")