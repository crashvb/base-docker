#!/bin/bash

export EP_GPG_KEY_LENGTH=${EP_GPG_KEY_LENGTH:-8192}
export EP_PWGEN_LENGTH=${EP_PWGEN_LENGTH:-64}
export EP_RUN=/var/local/container_initialized
export EP_SECRETS_ROOT=${EP_SECRETS_ROOT:-/run/secrets}
export EP_SSH_KEY_LENGTH=${EP_GPG_KEY_LENGTH:-8192}

function log
{
	echo -e "$(date +%Y-%m-%d_%H:%M:%S) | $(basename $0) | $@"
}
export -f log

# 1 - secret name
# 2 - real name
# 3 - email
function generate_gpgkey
{
	key=${1,,}.gpg
	secrets=$EP_SECRETS_ROOT/$key

	export GNUPGHOME=$(eval echo ~${1,,})/.gnupg

	if [[ ! -d $EP_SECRETS_ROOT ]] ; then
		log "WARN: Creating secrets root: $EP_SECRETS_ROOT ..."
		mkdir --parents $EP_SECRETS_ROOT
	fi

	mkdir --mode=0700 --parents $GNUPGHOME

	tmp=$(gpg --list-secret-keys 2>/devnull)
	if [[ -e $secrets ]] ; then
		log "Importing $key from secrets ..."
		gpg --allow-secret-key-import --import --verbose $secrets
	elif [[ -z $tmp || -n $tmp ]] ; then
		log "Generating $key in secrets ..."

		cat <<- EOF | gpg --batch --gen-key --verbose
			Key-Type: 1
			Key-Length: $EP_GPG_KEY_LENGTH
			Name-Real: ${2:-${1,,}}
			Name-Email: ${3:-${1,,}@$HOSTNAME}
			Expire-Date: 0
		EOF
		gpg --armor --export --output $secrets
		gpg --armor --export-secret-key >> $secrets
	else
		log "Importing $key from container ..."
		gpg --armor --export --output $secrets
		gpg --armor --export-secret-key >> $secrets
	fi
}
export -f generate_gpgkey

# 1 - name
function generate_password
{
	secrets=$EP_SECRETS_ROOT/${1,,}_password
	var=${1^^}_PASSWORD

	if [[ ! -d $EP_SECRETS_ROOT ]] ; then
		log "WARN: Creating secrets root: $EP_SECRETS_ROOT ..."
		mkdir --parents $EP_SECRETS_ROOT
	fi

	if [[ -e $secrets ]] ; then
		log "Importing $var from secrets ..."
		export $var="$(<$secrets)"
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

function generate_sshkey
{
	# Note: ssh-keygen -f id_rsa -y > id_rsa.pub
	key=id_rsa.${1,,}
	secrets=$EP_SECRETS_ROOT/$key
	userkey=$(eval echo ~${1,,})/.ssh/id_rsa

	if [[ ! -d $EP_SECRETS_ROOT ]] ; then
		log "WARN: Creating secrets root: $EP_SECRETS_ROOT ..."
		mkdir --parents $EP_SECRETS_ROOT
	fi

	mkdir --parents $(dirname $userkey)

	if [[ -e $secrets ]] ; then
		log "Importing $key from secrets ..."
		ln --force --symbolic $secrets $userkey
	elif [[ ! -e $userkey  ]] ; then
		log "Generating $key in secrets ..."
		ssh-keygen -b $EP_SSH_KEY_LENGTH -f $secrets -t rsa -N ''
		ln --symbolic $secrets $userkey
	else
		log "Importing $key from container ..."
		install --mode=0400 $userkey $secrets
		ln --force --symbolic $secrets $userkey
	fi
}
export -f generate_sshkey

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
			log "	$key=${!key}"
		done < "$1.defaults"
	fi

	if [[ -z $3 ]] ; then
		envsubst < "$1.template" > "$2"
	else
		envsubst "$3" < "$1.template" > "$2"
	fi
}
export -f render_template

