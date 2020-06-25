import gettext
import os

debug = True

# Set the local directory
localedir = 'xxx-LOCALEPATH-xxx'
if not os.path.isabs(localedir):
  localedir = os.path.dirname(__file__) + os.sep + localedir
  
domain = 'xxx-DOMAIN-xxx'

if debug:
  print ('localedir: %s, domain: %s' % (localedir, domain))
  
# Set up your magic function
t = gettext.translation(domain, localedir)
tr = t.gettext

