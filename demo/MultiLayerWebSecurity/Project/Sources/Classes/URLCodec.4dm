

shared singleton Class constructor()
	
shared Function decode($encoded : Text) : Text
	return This:C1470._decodeCore($encoded; True:C214)
	
	
shared Function decodePath($encoded : Text) : Text
	return This:C1470._decodeCore($encoded; False:C215)
	
	
Function _decodeCore($encoded : Text; $plusIsSpace : Boolean) : Text
	var $blob : Blob
	var $pos; $len; $code : Integer
	var $char; $hex; $result : Text
	
	SET BLOB SIZE:C606($blob; 0)
	$len:=Length:C16($encoded)
	$pos:=1
	
	While ($pos<=$len)
		$char:=$encoded[[$pos]]
		Case of 
			: ($char="+") & ($plusIsSpace)
				SET BLOB SIZE:C606($blob; BLOB size:C605($blob)+1; 0x0020)
				
			: ($char="%")
				If (($pos+2)<=$len)
					$hex:=$encoded[[$pos+1]]+$encoded[[$pos+2]]
					If (This:C1470._isHexPair($hex))
						$code:=Num:C11($hex; 16)
						SET BLOB SIZE:C606($blob; BLOB size:C605($blob)+1; $code)
						$pos:=$pos+2
					Else 
						SET BLOB SIZE:C606($blob; BLOB size:C605($blob)+1; 0x0025)
					End if 
				Else 
					SET BLOB SIZE:C606($blob; BLOB size:C605($blob)+1; 0x0025)
				End if 
				
			Else 
				$code:=Character code:C91($char)
				If ($code<=127)
					SET BLOB SIZE:C606($blob; BLOB size:C605($blob)+1; $code)
				Else 
					
					SET BLOB SIZE:C606($blob; BLOB size:C605($blob)+1; 0x003F)
				End if 
		End case 
		$pos:=$pos+1
	End while 
	
	$result:=BLOB to text:C555($blob; UTF8 text without length:K22:17)
	return $result
	
Function _isHexPair($s : Text) : Boolean
	var $c1; $c2 : Text
	$c1:=Lowercase:C14($s[[1]])
	$c2:=Lowercase:C14($s[[2]])
	return ((($c1>="0") & ($c1<="9")) | (($c1>="a") & ($c1<="f"))) & \
		((($c2>="0") & ($c2<="9")) | (($c2>="a") & ($c2<="f")))