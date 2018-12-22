//  https://stackoverflow.com/questions/50846404/how-do-i-get-the-selected-text-from-a-wkwebview-from-objective-c
function getSelectionAndSendMessage()
{
    var txt = document.getSelection().toString() ;
    window.webkit.messageHandlers.newSelectionDetected.postMessage(txt) ;
}
document.onmouseup   = getSelectionAndSendMessage ;
document.onkeyup     = getSelectionAndSendMessage ;

//  https://stackoverflow.com/questions/21224327/how-to-detect-middle-mouse-button-click/21224428
document.body.onclick = function (e) {
  if (e && (e.which == 2 || e.button == 4 )) {
    sendLink;
  }
}
function middleLink()
{
    window.webkit.messageHandlers.newWindowWithUrlDetected.postMessage(this.href) ;
}

//  https://stackoverflow.com/questions/51894733/how-to-get-mouse-over-urls-into-wkwebview-with-swift/51899392#51899392
function sendLink()
{
    window.webkit.messageHandlers.newUrlDetected.postMessage(this.href) ;
}

var allLinks = document.links;
for(var i=0; i< allLinks.length; i++)
{
    allLinks[i].onmouseover = sendLink ;
}

