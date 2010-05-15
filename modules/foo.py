import iqx


def bar(event):
  print event
  return {"foo": 1}


iqx.bind('irc', 'pubmsg', bar)