#!/bin/bash

export EP_RUN=/var/local/container_initialized

function log
{
	echo "$(date +%Y-%m-%d_%H:%M:%S) | $(basename $0) | $@"
}
export -f log

# 1 - name
function generate_password
{
	pwgen_length=${EP_PWGEN_LENGTH:-64}
	var="${1^^}_PASSWORD"
	if [[ -z "$(eval echo \$$var)" ]] ; then
		log "Generating $var ..."
		export $var=$(pwgen --capitalize --numerals --secure -1 $pwgen_length)
		install --mode=0400 /dev/null /root/${1}_password
		echo "$var=$(eval echo \$$var)" > /root/${1}_password
	else
		log "Importing $var ..."
	fi
}
export -f generate_password

# 1 - template / defaults prefix
# 2 - target
# 3 - shell format (optional)
function render_template
{
	log "Generating: $(basename $2) ..."
	if [[ -f "$1.defaults" ]] ; then
		while IFS='=' read -r key value
		do
			eval "export $key=\${$key:=$value}"
			log "	$key=$(eval echo \$$key)"
		done < "$1.defaults"
	fi

	if [[ -z $3 ]] ; then
		envsubst < "$1.template" > "$2"
	else
		envsubst "$3" < "$1.template" > "$2"
	fi
}
export -f render_template

