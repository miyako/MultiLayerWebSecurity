
property _path : Text
property handlers : Collection

shared singleton Class constructor()
	This:C1470._path:=File:C1566("/PACKAGE/Project/Sources/HTTPHandlers.json").path
	This:C1470.handlers:=New shared collection:C1527
	This:C1470._load()
	
shared Function getHandlers() : Collection
	return This:C1470.handlers.copy()
	
shared Function addHandler($h : Object) : Object
	var $v : Object
	$v:=This:C1470._validate($h)
	If ($v.valid)
		var $shared : Object
		Use (This:C1470.handlers)
			$shared:=OB Copy:C1225($h; ck shared:K85:29; This:C1470.handlers)
			This:C1470.handlers.push($shared)
		End use 
		This:C1470._save()
		return New object:C1471("success"; True:C214; "message"; "Handler added. Restart web server to apply.")
	End if 
	return New object:C1471("success"; False:C215; "message"; $v.message)
	
shared Function updateHandler($index : Integer; $h : Object) : Object
	var $v : Object
	$v:=This:C1470._validate($h)
	If ($v.valid)
		If (($index>=0) & ($index<This:C1470.handlers.length))
			var $shared : Object
			Use (This:C1470.handlers)
				$shared:=OB Copy:C1225($h; ck shared:K85:29; This:C1470.handlers)
				This:C1470.handlers[$index]:=$shared
			End use 
			This:C1470._save()
			return New object:C1471("success"; True:C214; "message"; "Handler updated. Restart web server to apply.")
		End if 
		return New object:C1471("success"; False:C215; "message"; "Invalid index")
	End if 
	return New object:C1471("success"; False:C215; "message"; $v.message)
	
shared Function deleteHandler($index : Integer) : Boolean
	If (($index>=0) & ($index<This:C1470.handlers.length))
		Use (This:C1470.handlers)
			This:C1470.handlers.remove($index)
		End use 
		This:C1470._save()
		return True:C214
	End if 
	return False:C215
	
shared Function replaceAll($newHandlers : Collection)
	Use (This:C1470)
		If ($newHandlers#Null:C1517)
			This:C1470.handlers:=$newHandlers.copy(ck shared:K85:29; This:C1470.handlers)
		Else 
			This:C1470.handlers:=New shared collection:C1527
		End if 
	End use 
	This:C1470._save()
	
shared Function exportJSON() : Text
	return JSON Stringify:C1217(This:C1470.handlers; *)
	
shared Function reload()
	This:C1470._load()
	
	
Function _validate($h : Object) : Object
	If ($h=Null:C1517)
		return New object:C1471("valid"; False:C215; "message"; "Handler object is Null")
	End if 
	If (Not:C34(OB Is defined:C1231($h; "class")))
		return New object:C1471("valid"; False:C215; "message"; "Missing 'class'")
	End if 
	If (Not:C34(OB Is defined:C1231($h; "method")))
		return New object:C1471("valid"; False:C215; "message"; "Missing 'method'")
	End if 
	If ((Not:C34(OB Is defined:C1231($h; "pattern"))) & (Not:C34(OB Is defined:C1231($h; "regexPattern"))))
		return New object:C1471("valid"; False:C215; "message"; "Need 'pattern' or 'regexPattern'")
	End if 
	return New object:C1471("valid"; True:C214; "message"; "OK")
	
	
Function _load()
	var $file : 4D:C1709.File
	$file:=File:C1566(This:C1470._path)
	If ($file.exists)
		var $parsed : Collection
		$parsed:=JSON Parse:C1218($file.getText("UTF-8"))
		If ($parsed#Null:C1517)
			Use (This:C1470)
				This:C1470.handlers:=$parsed.copy(ck shared:K85:29; This:C1470.handlers)
			End use 
		End if 
	End if 
	
Function _save()
	File:C1566(This:C1470._path).setText(JSON Stringify:C1217(This:C1470.handlers; *); "UTF-8")