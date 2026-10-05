

shared singleton Class constructor()
	
shared Function canonicalize($url : Text) : Text
	var $work; $previous; $path; $query : Text
	var $queryPos; $i; $maxPasses : Integer
	
	If ($url=Null:C1517) | (Length:C16($url)=0)
		return ""
	End if 
	
	$maxPasses:=Num:C11(cs:C1710.ConfigManager.me.get("waf.maxDecodePasses"))
	If ($maxPasses<=0)
		$maxPasses:=3
	End if 
	
	$work:=$url
	
	$queryPos:=Position:C15("?"; $work)
	If ($queryPos>0)
		$path:=Substring:C12($work; 1; $queryPos-1)
		$query:=Substring:C12($work; $queryPos+1)
	Else 
		$path:=$work
		$query:=""
	End if 
	
	For ($i; 1; $maxPasses)
		$previous:=$path
		$path:=cs:C1710.URLCodec.me.decodePath($path)
		If ($path=Null:C1517)
			$path:=""
		End if 
		If ($path=$previous)
			$i:=$maxPasses+1
		End if 
	End for 
	
	If (Length:C16($query)>0)
		$query:=cs:C1710.URLCodec.me.decode($query)
		If ($query=Null:C1517)
			$query:=""
		End if 
	End if 
	
	$path:=This:C1470._stripDangerous($path)
	$query:=This:C1470._stripDangerous($query)
	
	$path:=Lowercase:C14($path)
	
	$path:=This:C1470._resolveDotSegments($path)
	If ($path="")
		return ""
	End if 
	
	If (Length:C16($query)>0)
		return $path+"?"+$query
	End if 
	return $path
	
	
shared Function isSafe($normalizedUrl : Text) : Boolean
	var $i; $code; $maxDepth : Integer
	var $segments : Collection
	var $strict : Boolean
	
	If (Length:C16($normalizedUrl)=0)
		return False:C215
	End if 
	If (Substring:C12($normalizedUrl; 1; 1)#"/")
		return False:C215
	End if 
	If (Position:C15(".."; $normalizedUrl)>0)
		return False:C215
	End if 
	If (Position:C15("\\"; $normalizedUrl)>0)
		return False:C215
	End if 
	
	$strict:=Bool:C1537(cs:C1710.ConfigManager.me.get("waf.strictASCII"))
	
	For ($i; 1; Length:C16($normalizedUrl))
		$code:=Character code:C91($normalizedUrl[[$i]])
		Case of 
			: ($code<32)
				return False:C215
			: ($code=127)
				return False:C215
			: ($code>126) & ($strict)
				return False:C215
		End case 
	End for 
	
	$maxDepth:=Num:C11(cs:C1710.ConfigManager.me.get("waf.maxPathDepth"))
	If ($maxDepth<=0)
		$maxDepth:=20
	End if 
	$segments:=Split string:C1554($normalizedUrl; "/")
	If ($segments.length>$maxDepth)
		return False:C215
	End if 
	
	return True:C214
	
	
Function _stripDangerous($s : Text) : Text
	$s:=Replace string:C233($s; Char:C90(0); "")
	$s:=Replace string:C233($s; Char:C90(13); "")
	$s:=Replace string:C233($s; Char:C90(10); "")
	return $s
	
Function _resolveDotSegments($path : Text) : Text
	var $segments; $resolved : Collection
	var $seg : Text
	var $leadingSlash : Boolean
	var $i : Integer
	
	$leadingSlash:=(Substring:C12($path; 1; 1)="/")
	$segments:=Split string:C1554($path; "/")
	$resolved:=New collection:C1472
	
	For ($i; 0; $segments.length-1)
		$seg:=String:C10($segments[$i])
		Case of 
			: ($seg=".")
			: ($seg="..")
				If ($resolved.length=0)
					return ""
				End if 
				$resolved.pop()
			: ($seg="")
			Else 
				$resolved.push($seg)
		End case 
	End for 
	
	If ($leadingSlash)
		return "/"+$resolved.join("/")
	Else 
		return $resolved.join("/")
	End if 