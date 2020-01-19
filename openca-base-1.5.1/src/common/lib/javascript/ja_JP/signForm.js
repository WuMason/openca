<!--

function signForm(theForm, theWindow){
        if (navigator.appName == "Netscape"){
                signFormN(theForm, theWindow);
        } else {
                signFormIE(theForm,theWindow);
        }
        theForm.submit();
}

function signFormN(theForm, theWindow) {
  var signedText;

  var sObject;
  var result;
  try {
    // alert ('SecCLABプラグインをテストしています。');
    sObject = new CLABSignString();
    // alert ('SecCLABプラグインを使用しています。');
    if (sObject == undefined) alert('SecCLABプラグインの使用に失敗しました。');
    var status = {value:0};
    var len = {value:0};
    try {
      result = sObject.signString(window,theForm.text.value,theForm.text.value.length,status,len);
      if (status.value != sObject.STATUS_OK) {
        alert("ユーザによって中止されたか、有効なユーザ証明書ではありません。");
        return false;
      }
    } catch(ex) {
        alert("ユーザによって中止されたか、有効なユーザ証明書ではありません。");
        return false;
    }
    signedText = String2Base64(result); //String2Hex(result);
  } catch(ex) {
    // alert ('暗号化されたJavascriptオブジェクトを使用しています。');
    signedText = theWindow.crypto.signText(theForm.text.value, "ask");
  }

  if ( signedText.length < 100 ) {
    alert( "続行するには署名が必要です!" );
    return false;
  }

  theForm.signature.value = signedText;
}

function Hex(v)
{
  var hexstring="0123456789ABCDEF";
  return hexstring[v];
}

function String2Hex(str){
  var s = "";
  var hnible;
  var lnible;
  for (var i=0;i < str.length;i++){
    hnible = Hex(str.charCodeAt(i) >> 4);
    lnible = Hex(str.charCodeAt(i) & 0x0f);
    s = s + hnible + lnible;
  }
  return s;
}

function base64ToAscii(c)
{
	var theChar = 0;
	
	if (0 <= c && c <= 25)
	{
		theChar = String.fromCharCode(c + 65);
	}
	else if (26 <= c && c <= 51)
	{
		theChar = String.fromCharCode(c - 26 + 97);
	}
	else if (52 <= c && c <= 61)
	{
		theChar = String.fromCharCode(c - 52 + 48);
	}
	else if (c == 62)
	{
		theChar = '+';
	}
	else if( c == 63 )
	{
		theChar = '/';
	}
	else
	{
		theChar = String.fromCharCode(0xFF);
	}

	return theChar;
}


function String2Base64(str) {
	var result = "";
	var i = 0;
	var sextet = 0;
	var leftovers = 0;
	var octet = 0;

	for (i=0; i < str.length; i++) {
		octet = str.charCodeAt(i);
		switch( i % 3 )
		{
			case 0:
			{
				sextet = ( octet & 0xFC ) >> 2 ;
				leftovers = octet & 0x03 ;

				// sextet contains first character in quadruple
				break;
			}

			case 1:
			{
				sextet = ( leftovers << 4 ) | ( ( octet & 0xF0 ) >> 4 );
				leftovers = octet & 0x0F ;

				// sextet contains 2nd character in quadruple
				break;
			}

			case 2:
			{
				sextet = ( leftovers << 2 ) | ( ( octet & 0xC0 ) >> 6 ) ;
				leftovers = ( octet & 0x3F ) ;

				// sextet contains third character in quadruple
				// leftovers contains fourth character in quadruple
				break;
			}
		}

		result = result + base64ToAscii(sextet);

		// don't forget about the fourth character if it is there
		if( (i % 3) == 2 )
		{
			result = result + base64ToAscii(leftovers);
		} 

	}

	// figure out what to do with leftovers and padding
	switch( str.length % 3 )
	{
		case 0:
		{
			// an even multiple of 3, nothing left to do
			break ;
		}
		case 1:
		{
			// one 6-bit chars plus 2 leftover bits
			leftovers =  leftovers << 4 ;
			result = result + base64ToAscii(leftovers);
			result = result + "==";
			break ;
		}
		case 2:
		{
			// two 6-bit chars plus 4 leftover bits
			leftovers = leftovers << 2 ;
			result = result + base64ToAscii(leftovers);
			result = result + "=";
			break ;
		}
	}

	return result;
}

// -->
