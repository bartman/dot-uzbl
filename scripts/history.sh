#!/bin/bash
#TODO: strip 'http://' part
# you probably really want this in your $XDG_DATA_HOME (eg $HOME/.local/share/uzbl/history)
history_file=$HOME/.uzbl/data/history
echo "$8 $6 $7" >> $history_file
