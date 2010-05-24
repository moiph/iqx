import iqx
import urllib2
import re

def bar(event):
  print event
  msgParts = event['data']['message'].split(' ')
  target = event['data']['target']
  returnMsg = null

  if msgParts[0] == ".ud":
     url = "http://urbandictionary.com/define.php?term=" + msgParts[1]
     usock = urllib2.urlopen(url)
     data = usock.read()
     usock.close()

     pDef  = re.compile("div class='definition'>(.+?)</div>")
     pRepl = re.compile("<[^<]+>")
     match = pDef.search(data)
     if match:
        result = match.group(1)
        result = pRepl.sub('', result)
        returnMsg = result
     else:
        returnMsg = "error :("

  if returnMsg
    return {"target": target, "msg": returnMsg}

iqx.bind('irc', 'pubmsg', bar)
