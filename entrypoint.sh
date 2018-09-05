#!/bin/bash

export EP_PWGEN_LENGTH=${EP_PWGEN_LENGTH:-64}
export EP_RUN=/var/local/container_initialized
export EP_SECRETS_ROOT=${EP_SECRETS_ROOT:-/run/secrets}

function log
{
	echo "$(date +%Y-%m-%d_%H:%M:%S) | $(basename $0) | $@"
}
export -f log

# 1 - name
function generate_password
{
	secrets=$EP_SECRETS_ROOT/${1,,}_password
	var=${1^^}_PASSWORD

	if [[ ! -d $EP_SECRETS_ROOT ]] ; then
		log "WARN: Creating secrets root: $EP_SECRETS_ROOT ..."
		mkdir --parents $EP_SECRETS_ROOT
	fi

	if [[ -f $secrets ]] ; then
		log "Importing $var from secrets ..."
		export $var=$(<$secrets)
	elif [[ -z "$(eval echo \$$var)" ]] ; then
		log "Generating $var in secrets ..."
		export $var=$(pwgen --capitalize --numerals --secure -1 $EP_PWGEN_LENGTH)
		install --mode=0400 /dev/null $secrets
		echo $(eval echo \$$var) > $secrets
	else
		log "Importing $var from environment ..."
		echo $(eval echo \$$var) > $secrets
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

