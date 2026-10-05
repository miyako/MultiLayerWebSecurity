

shared singleton Class constructor()
	
shared Function validate($headersRaw : Text) : Object
	var $bytes : Integer
	$bytes:=Length:C16($headersRaw)
	
	
	var $maxBytes : Integer
	$maxBytes:=Num:C11(cs:C1710.ConfigManager.me.get("validation.maxHeaderBytes"))
	If ($maxBytes<=0)
		$maxBytes:=8192
	End if 
	
	If ($bytes>$maxBytes)
		return New object:C1471(\
			"valid"; False:C215; \
			"code"; 431; \
			"reason"; "Header block "+String:C10($bytes)+"B exceeds cap "+String:C10($maxBytes)+"B"; \
			"bytes"; $bytes)
	End if 
	
	
	If (Position:C15(Char:C90(0); $headersRaw)>0)
		return New object:C1471(\
			"valid"; False:C215; \
			"code"; 400; \
			"reason"; "Null byte in header block"; \
			"bytes"; $bytes)
	End if 
	
	
	var $maxLineBytes : Integer
	$maxLineBytes:=Num:C11(cs:C1710.ConfigManager.me.get("validation.maxHeaderLineBytes"))
	If ($maxLineBytes<=0)
		$maxLineBytes:=4096
	End if 
	
	var $lines : Collection
	$lines:=Split string:C1554($headersRaw; Char:C90(13)+Char:C90(10))
	
	var $i : Integer
	For ($i; 0; $lines.length-1)
		var $line : Text
		$line:=String:C10($lines[$i])
		
		If (Length:C16($line)>$maxLineBytes)
			return New object:C1471(\
				"valid"; False:C215; \
				"code"; 431; \
				"reason"; "Header line "+String:C10($i)+" is "+String:C10(Length:C16($line))+" chars (cap "+String:C10($maxLineBytes)+")"; \
				"bytes"; $bytes)
		End if 
		
		
		var $colonPos : Integer
		$colonPos:=Position:C15(":"; $line)
		If ($colonPos>0)
			var $value : Text
			$value:=Substring:C12($line; $colonPos+1)
			
			If (Position:C15(Char:C90(10); $value)>0) | (Position:C15(Char:C90(13); $value)>0)
				return New object:C1471(\
					"valid"; False:C215; \
					"code"; 400; \
					"reason"; "CRLF injection detected in header value (line "+String:C10($i)+")"; \
					"bytes"; $bytes)
			End if 
		End if 
	End for 
	
	return New object:C1471("valid"; True:C214; "code"; 200; "reason"; ""; "bytes"; $bytes)
	