
property allowedTypes : Collection
property uploadPath : Text
property uploadCount : Integer
property totalBytes : Integer

shared singleton Class constructor()
	This:C1470.allowedTypes:=New shared collection:C1527(\
		"application/pdf"; "image/jpeg"; "image/png"; "image/gif"; \
		"text/plain"; "application/json"; "text/csv")
	This:C1470.uploadPath:="/PACKAGE/Files/uploads/"
	This:C1470.uploadCount:=0
	This:C1470.totalBytes:=0
	
shared Function handleUpload($req : 4D:C1709.IncomingMessage) : 4D:C1709.OutgoingMessage
	var $resp : 4D:C1709.OutgoingMessage
	$resp:=4D:C1709.OutgoingMessage.new()
	
	
	var $gate : Object
	$gate:=cs:C1710.DoSGuard.me._gate($req)
	If (Not:C34($gate.accept))
		
		cs:C1710.RequestLogger.me.log("BLOCKED_UPLOAD"; $gate.ip; "POST"; $req.url; 403; "Defense gate denied"; "")
		return cs:C1710.DoSGuard.me._error($resp; 403; "Forbidden"; "Defense gate denied")
	End if 
	
	var $ip : Text
	$ip:=$gate.ip
	var $ipMgr : cs:C1710.IPManager
	$ipMgr:=cs:C1710.IPManager.me
	var $logger : cs:C1710.RequestLogger
	$logger:=cs:C1710.RequestLogger.me
	
	
	var $ct : Text
	$ct:=$req.getHeader("Content-Type")
	var $ok : Boolean
	$ok:=False:C215
	var $i : Integer
	For ($i; 0; This:C1470.allowedTypes.length-1)
		If (Position:C15(String:C10(This:C1470.allowedTypes[$i]); $ct)>0)
			$ok:=True:C214
		End if 
	End for 
	
	If (Not:C34($ok))
		$logger.log("INVALID_UPLOAD"; $ip; "POST"; $req.url; 415; "Type: "+$ct; "")
		var $allowedStr : Text
		$allowedStr:=""
		For ($i; 0; This:C1470.allowedTypes.length-1)
			If ($i>0)
				$allowedStr:=$allowedStr+", "
			End if 
			$allowedStr:=$allowedStr+String:C10(This:C1470.allowedTypes[$i])
		End for 
		return cs:C1710.DoSGuard.me._error($resp; 415; "Unsupported Media Type"; "Allowed: "+$allowedStr)
	End if 
	
	var $cl : Text
	$cl:=$req.getHeader("Content-Length")
	var $maxMB : Integer
	$maxMB:=Num:C11(cs:C1710.ConfigManager.me.get("validation.maxBodySizeMB"))
	If ($maxMB<=0)
		$maxMB:=10
	End if 
	If ($cl#"")
		If (Num:C11($cl)>($maxMB*1048576))
			$logger.log("OVERSIZED_UPLOAD"; $ip; "POST"; $req.url; 413; $cl+" bytes"; "")
			return cs:C1710.DoSGuard.me._error($resp; 413; "Payload Too Large"; "Max "+String:C10($maxMB)+" MB")
		End if 
	End if 
	
	var $ext : Text
	Case of 
		: (Position:C15("pdf"; $ct)>0)
			$ext:=".pdf"
		: (Position:C15("jpeg"; $ct)>0)
			$ext:=".jpg"
		: (Position:C15("png"; $ct)>0)
			$ext:=".png"
		: (Position:C15("gif"; $ct)>0)
			$ext:=".gif"
		: (Position:C15("plain"; $ct)>0)
			$ext:=".txt"
		: (Position:C15("json"; $ct)>0)
			$ext:=".json"
		: (Position:C15("csv"; $ct)>0)
			$ext:=".csv"
		Else 
			$ext:=".bin"
	End case 
	
	var $rawName; $fileName : Text
	$rawName:=$req.urlQuery.fileName
	If ($rawName="")
		$fileName:="upload_"+String:C10(Milliseconds:C459)
	Else 
		$fileName:=cs:C1710.URLCodec.me.decode($rawName)
		$fileName:=This:C1470._sanitizeFileName($fileName)
		If ($fileName="")
			$logger.log("INVALID_UPLOAD"; $ip; "POST"; $req.url; 400; "Illegal filename after sanitization: "+$rawName; "")
			return cs:C1710.DoSGuard.me._error($resp; 400; "Bad Request"; "Illegal filename")
		End if 
	End if 
	
	var $folder : 4D:C1709.Folder
	$folder:=Folder:C1567(This:C1470.uploadPath)
	If (Not:C34($folder.exists))
		$folder.create()
	End if 
	
	var $file : 4D:C1709.File
	$file:=File:C1566(This:C1470.uploadPath+$fileName+$ext)
	$file.create()
	$file.setContent($req.getBlob())
	
	
	var $sizeAtomic : Integer
	$sizeAtomic:=Num:C11($file.size)
	Use (This:C1470)
		This:C1470.uploadCount:=This:C1470.uploadCount+1
		This:C1470.totalBytes:=This:C1470.totalBytes+$sizeAtomic
	End use 
	
	$logger.log("UPLOAD_OK"; $ip; "POST"; $req.url; 201; $fileName+$ext+" ("+String:C10($file.size)+"B)")
	
	var $body : Object
	$body:=New object:C1471("status"; "success"; \
		"file"; New object:C1471("name"; $fileName+$ext; "size"; $file.size; "type"; $ct))
	$resp.setBody(JSON Stringify:C1217($body))
	$resp.setHeader("Content-Type"; "application/json")
	$resp.setStatus(201)
	return $resp
	
	
Function _sanitizeFileName($name : Text) : Text
	var $clean : Text
	$clean:=$name
	
	$clean:=Replace string:C233($clean; Char:C90(0); "")
	$clean:=Replace string:C233($clean; Char:C90(13); "")
	$clean:=Replace string:C233($clean; Char:C90(10); "")
	$clean:=Replace string:C233($clean; Char:C90(9); "")
	
	$clean:=Replace string:C233($clean; "/"; "")
	$clean:=Replace string:C233($clean; "\\"; "")
	$clean:=Replace string:C233($clean; ":"; "")
	
	While ((Length:C16($clean)>0) & (Substring:C12($clean; 1; 1)="."))
		$clean:=Substring:C12($clean; 2)
	End while 
	
	While (Position:C15(".."; $clean)>0)
		$clean:=Replace string:C233($clean; ".."; ".")
	End while 
	
	If (Length:C16($clean)>200)
		$clean:=Substring:C12($clean; 1; 200)
	End if 
	
	return $clean