

#DECLARE($url : Text; $headers : Text; $ipClient : Text; $ipServer : Text; $username : Text; $password : Text)

var $ip : Text
$ip:=cs:C1710.DoSGuard.me._extractIPFromHeader($headers; $ipClient)

cs:C1710.RequestLogger.me.log("UNKNOWN_URL"; $ip; "GET"; $url; 404; \
"No HTTPHandler matched — unknown URL")


If (Bool:C1537(cs:C1710.ConfigManager.me.get("security.unknownURLStrikes")))
	If (cs:C1710.DoSGuard.me._isMasterOn())
		cs:C1710.IPManager.me.blockIP($ip; 60; "Unknown URL probe: "+$url)
	End if 
End if 


