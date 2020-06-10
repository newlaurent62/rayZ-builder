#!/bin/bash

if [ "$(wmctrl -l | grep Catia)" != "" ]; then 
  wmctrl -i -a $(wmctrl -l | grep -E "^.+?\s+.+?\s+.+?\s+Catia$" | awk '{print $1}')
else 
  catia 
fi
