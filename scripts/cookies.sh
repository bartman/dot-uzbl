#!/bin/bash
# this is an example script of how you could manage your cookies..
# we use the cookies.txt format (See http://kb.mozillazine.org/Cookies.txt)
# This is one textfile with entries like this:
# kb.mozillazine.org	FALSE	/	FALSE	1146030396	wikiUserID	16993
# domain alow-read-other-subdomains path http-required expiration name value  
# you probably want your cookies config file in your $XDG_CONFIG_HOME ( eg $HOME/.config/uzbl/cookies)
# Note. in uzbl there is no strict definition on what a session is.  it's YOUR job to clear cookies marked as end_session if you want to keep cookies only valid during a "session"
# MAYBE TODO: allow user to edit cookie before saving. this cannot be done with zenity :(
# TODO: different cookie paths per config (eg per group of uzbl instances)

# TODO: correct implementation.
# see http://curl.haxx.se/rfc/cookie_spec.html
# http://en.wikipedia.org/wiki/HTTP_cookie

# TODO : check expires= before sending.
# write sample script that cleans up cookies dir based on expires attribute.
# TODO: check uri against domain attribute. and path also.
# implement secure attribute.
# support blocking or not for 3rd parties
# http://kb.mozillazine.org/Cookies.txt
# don't always append cookies, sometimes we need to overwrite

config_file=$HOME/.uzbl/configs/cookies
cookie_file=$HOME/.uzbl/data/cookies.txt

which zenity &>/dev/null || exit 2

# Example cookie:
# test_cookie=CheckForPermission; expires=Thu, 07-May-2009 19:17:55 GMT; path=/; domain=.doubleclick.net

# uri=$6
# uri=${uri/http:\/\/} # strip 'http://' part
# host=${uri/\/*/}
action=$8 # GET/PUT
host=$9
shift
path=$9
shift
cookie=$9

field_domain=$host
field_path=$path
field_name=
field_value=
field_exp='end_session'


# FOR NOW LETS KEEP IT SIMPLE AND JUST ALWAYS PUT AND ALWAYS GET
function parse_cookie () {
	IFS=$';'
	first_pair=1
	for pair in $cookie
	do
		if [ "$first_pair" == 1 ]
		then
			field_name=${pair%%=*}
			field_value=${pair#*=}
			first_pair=0
		else
			read -r pair <<< "$pair" #strip leading/trailing wite space
			key=${pair%%=*}
			val=${pair#*=}
			[ "$key" == expires ] && field_exp=`date -u -d "$val" +'%s'`
			# TODO: domain
			[ "$key" == path ] && field_path=$val
		fi
	done
	unset IFS
}

# match cookies in cookies.txt againsh hostname and path
function get_cookie () {
        local res=false
        while read  c_domain  c_alow_read_other_subdomains  c_path  c_http_required  c_expiration  c_name  c_value ; do

                if [[ "$c_domain" != "$host" ]] ; then
                        # no direct match, can we do domain match?
                        [[ "$c_alow_read_other_subdomains" = 'TRUE' ]] || continue
                        # is $host a subdomain of $c_domain?
                        [[ "$c_domain" = "${c_domain%$host}" ]]        && continue
echo >&2 "       - decided that $host is a subdomain of $c_domain"
                fi

echo >&2 "       - HAVE $c_domain    $c_path    $c_value"

                #if [[ -n "$path" ]] ; then
                #        echo >&2 "         - $c_path  $path  ${c_path#$path}"
                #        [[ "$c_path" = "${c_path#$path}" ]] && continue
                #        echo >&2 "           - pass"
                #fi

                cookie="$c_name=$c_value" 

                echo >&2 "COOKIE $cookie"

                res=true
        done < $cookie_file

        echo >&2 "...... $res"
        $res
}

[ $action == PUT ] && parse_cookie && echo -e "$field_domain\tFALSE\t$field_path\tFALSE\t$field_exp\t$field_name\t$field_value" >> $cookie_file
[ $action == GET ] && get_cookie && echo "$cookie"

exit


# TODO: implement this later.
# $1 = section (TRUSTED or DENY)
# $2 =url
function match () {
	sed -n "/$1/,/^\$/p" $config_file 2>/dev/null | grep -q "^$host"
}

function fetch_cookie () {
	cookie=`cat $cookie_file/$host.cookie`
}

function store_cookie () {
	echo $cookie > $cookie_file/$host.cookie
}

if match TRUSTED $host
then
	[ $action == PUT ] && store_cookie $host
	[ $action == GET ] && fetch_cookie && echo "$cookie"
elif ! match DENY $host
then
	[ $action == PUT ] &&                 cookie=`zenity --entry --title 'Uzbl Cookie handler' --text "Accept this cookie from $host ?" --entry-text="$cookie"` && store_cookie $host
	[ $action == GET ] && fetch_cookie && cookie=`zenity --entry --title 'Uzbl Cookie handler' --text "Submit this cookie to $host ?"   --entry-text="$cookie"` && echo $cookie
fi
exit 0
