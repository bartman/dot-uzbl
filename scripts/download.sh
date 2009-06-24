#!/bin/bash
# just an example of how you could handle your downloads
# try some pattern matching on the uri to determine what we should do

# Some sites block the default wget --user-agent...
WGET="wget --user-agent=Firefox"

if [[ $8 =~ .*(.torrent) ]] 
then
    pushd $HOME
    $WGET $8
else
    pushd $HOME
    $WGET $8
fi
popd
