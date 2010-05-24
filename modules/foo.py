import iqx

def bar(event):
  print event
  msgParts = event['data']['message'].split(' ')
  target = event['data']['target']
  returnMsg = null

  if msgParts[0] == ".8ball":
     returnMsg = "Definitely"

  if returnMsg:
    return {"target": target, "msg": returnMsg}


iqx.bind('irc', 'pubmsg', bar)
