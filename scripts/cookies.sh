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

function parse_cookie () {
	IFS=$';'
	local first_pair=1
	for pair in $cookie
	do
		if [ "$first_pair" == 1 ]
		then
			field_name=${pair%%=*}
			field_value=${pair#*=}
			first_pair=0
		else
			local key=${pair%%=*}
                        key=${key#* }
			local val=${pair#*=}
                        val=${val% *}
			[ "$key" == expires ] && field_exp=`date -u -d "$val" +'%s'`
			# TODO: domain
			[ "$key" == path ] && field_path=$val
		fi
	done
	unset IFS
}

# just append the cookie to the log
function write_cookie () {
        echo -e "$field_domain\tFALSE\t$field_path\tFALSE\t$field_exp\t$field_name\t$field_value" >> $cookie_file
}

# match cookies in cookies.txt againsh hostname and path
function print_cookies () {
        local res=false
        declare -a cookies
        while read  c_domain  c_alow_read_other_subdomains  c_path  c_http_required  c_expiration  c_name  c_value ; do

                if [[ "$c_domain" != "$host" ]] ; then
                        # no direct match, can we do domain match?
                        [[ "$c_alow_read_other_subdomains" = 'TRUE' ]] || continue
                        # is $host a subdomain of $c_domain?
                        [[ "$c_domain" = "${c_domain%$host}" ]]        && continue
                fi

                # if $path is specified, make sure that c_path 
                #if [[ -n "$path" ]] ; then
                #        echo >&2 "         - $c_path  $path  ${c_path#$path}"
                #        [[ "$c_path" = "${c_path#$path}" ]] && continue
                #        echo >&2 "           - pass"
                #fi

                cookies[${#cookies[@]}]="$c_name=$c_value" 
                res=true
        done < $cookie_file

        if $res ; then
                # only output the last (most recent) for each name
                local seen=:
                for (( n=${#cookies[@]} - 1 ; n>=0 ; n-- )) ; do
                        local cookie=${cookies[$n]}
                        local name=${cookie%%=*}
                        [[ "${seen/:$name:/}" = "$seen" ]] || continue
                        echo $cookie
                        seen="$seen$name:"
                done
        fi

        $res
}

function policy_match () {
        local section=$1
        local host=$2
        [ -f $config_file ] || return 0
	sed -n "/^ *$section *\$/,/^\$/p" $config_file 2>/dev/null | grep -q "^ *$host *\$"
}

function policy_add () {
        local section=$1
        local host=$2
        sed -i -e "s/^$section$/$section\n$host/" $config_file
}

policy_match DENY $host && exit 1

if [[ $action = GET ]] ; then
        print_cookies
        exit $?
fi

[[ $action = PUT ]] || exit 1

if ! parse_cookie ; then
        zenity --error --title='Uzbl Cookie Handler' \
            --text="Failed to parse cookie from $host for $path\n\n$cookie"
        exit 1
fi

if ! ( policy_match TRUSTED $host ) ; then

        choice=$(zenity --title 'Uzbl Cookie Handler' --list --radiolist \
                --height 310 \
                --text "We got this cookie from $host for $path\n\n${cookie//; /\\n}\n" \
                --column "" \
                --column "Action:" FALSE "Accept always" TRUE "Accept this time" FALSE "Deny this time" FALSE "Deny always")
        case $choice in
            Accept\ always)
                policy_add TRUSTED $host
                ;;
            Accept\ this\ time)
                # fall through
                ;;
            Deny\ always)
                policy_add DENY $host
                exit 1
                ;;
            *) # "Deny this time" and anything else
                exit 1
                ;;
        esac
fi

write_cookie
exit $?
