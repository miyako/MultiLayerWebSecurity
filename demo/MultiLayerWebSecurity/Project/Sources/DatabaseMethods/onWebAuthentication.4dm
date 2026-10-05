

#DECLARE($url : Text; $headers : Text; $ipClient : Text; $ipServer : Text; $username : Text; $password : Text)->$accept : Boolean


var $sonarResult : Object
$sonarResult:=cs:C1710.Sonar.me.intercept($ipClient; $url; $headers)


If (Session:C1714.storage.authData=Null:C1517)
	Use (Session:C1714.storage)
		Session:C1714.storage.authData:=New shared object:C1526
	End use 
End if 


If ($ipClient#"")
	Use (Session:C1714.storage.authData)
		Session:C1714.storage.authData.clientIP:=$ipClient
	End use 
End if 


Use (Session:C1714.storage.authData)
	Session:C1714.storage.authData.clientType:=String:C10($sonarResult.clientType)
	Session:C1714.storage.authData.clientFamily:=String:C10($sonarResult.clientFamily)
End use 


var $defenseResult : Object
$defenseResult:=cs:C1710.DoSGuard.me.authenticateRequest($url; $headers; $ipClient)


Use (Session:C1714.storage.authData)
	Session:C1714.storage.authData._authAccept:=$defenseResult.accept
	Session:C1714.storage.authData._authStatus:=$defenseResult.status
	Session:C1714.storage.authData._authReason:=$defenseResult.reason
	Session:C1714.storage.authData._authRetryAfterSec:=$defenseResult.retryAfterSec
	Session:C1714.storage.authData._authMs:=Milliseconds:C459
	Session:C1714.storage.authData._authUrl:=$url
End use 


Session:C1714.setPrivileges(New object:C1471("privilege"; "sonar"))

return True:C214