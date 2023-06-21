#!/bin/bash

export EP_PWGEN_LENGTH=${EP_PWGEN_LENGTH:-64}
export EP_RSA_KEY_SIZE=${EP_RSA_KEY_SIZE:-8192}
export EP_RUN=/var/local/container_initialized
export EP_SECRETS_ROOT=${EP_SECRETS_ROOT:-/run/secrets}
export EP_SSH_KEY_SIZE=${EP_SSH_KEY_SIZE:-${EP_RSA_KEY_SIZE}}
export EP_SSH_KEY_TYPE=${EP_SSH_KEY_TYPE:-rsa}
export EP_VALIDITY_DAYS=${EP_VALIDITY_DAYS:-30}

function log
{
	echo -e "$(date +%Y-%m-%d_%H:%M:%S) | $(basename -- "${0}") |" "$@"
}
export -f log

function ensure_secrets_root
{
	if [[ ! -d "${EP_SECRETS_ROOT}" ]] ; then
		log "WARN: Creating secrets root: ${EP_SECRETS_ROOT} ..."
		mkdir --parents "${EP_SECRETS_ROOT}"
	fi
}
export -f ensure_secrets_root

# 1 - secret name
# 2 - real name
# 3 - email
# 4 - user
function generate_gpgkey
{
	ensure_secrets_root

	local key="${1,,}.gpg"
	local name="${2:-${1,,}}"

	local secrets="${EP_SECRETS_ROOT}/${key}"
	local user="${4:-${1,,}}"

	export GNUPGHOME="$(eval echo ~"${user,,}")/.gnupg"
	mkdir --mode=0700 --parents "${GNUPGHOME}"

	# Even though it should be safe to invoke, let the caller do this for edge cases
	# where the corresponding passphrase should not be stored in $EP_SECRETS_ROOT ...
	# generate_password "${1,,}_gpg"
	local passphrase="$(eval echo "\$${1^^}_GPG_PASSWORD")"

	local tmp=$(gpg --list-secret-keys 2> /dev/null)
	if [[ -e "${secrets}" ]] ; then
		log "Importing ${key} from secrets ..."
		gpg --allow-secret-key-import --import --passphrase "${passphrase}" --pinentry-mode loopback --quiet "${secrets}"
	elif [[ ! "${tmp}" =~ "${name}" ]] ; then
		log "Generating ${key} in secrets ${passphrase:+[protected]} ..."

		# Note: "Passphrase: ${passphrase}" cannot be defined inline with a null passphrase.
		cat <<- EOF | gpg --batch --gen-key --keyid-format long --passphrase "${passphrase}" --pinentry-mode loopback --verbose
			Key-Type: RSA
			Key-Length: ${EP_RSA_KEY_SIZE}
			Subkey-Type: RSA
			Subkey-Length: ${EP_RSA_KEY_SIZE}
			Name-Real: ${name}
			Name-Email: ${3:-${1,,}@${HOSTNAME}}
			Expire-Date: ${EP_VALIDITY_DAYS}d
			%commit
		EOF
		gpg --armor --export --output "${secrets}" --quiet
		gpg --armor --export-secret-key --passphrase="${passphrase}" --pinentry-mode loopback >> "${secrets}"
		gpg --armor --export-secret-subkeys --passphrase="${passphrase}" --pinentry-mode loopback >> "${secrets}"
	else
		log "Importing ${key} from container ..."
		gpg --armor --export --output "${secrets}" --quiet
		gpg --armor --export-secret-key --passphrase="${passphrase}" --pinentry-mode loopback >> "${secrets}"
		gpg --armor --export-secret-subkeys --passphrase="${passphrase}" --pinentry-mode loopback >> "${secrets}"
	fi
}
export -f generate_gpgkey

# 1 - name
function generate_password
{
	ensure_secrets_root

	local secrets="${EP_SECRETS_ROOT}/${1,,}_password"
	local var="${1^^}_PASSWORD"

	if [[ -e "${secrets}" ]] ; then
		log "Importing ${var} from secrets ..."
		export "${var}"="$(<"${secrets}")"
	elif [[ -z "$(eval echo "\$${var}")" ]] ; then
		log "Generating ${var} in secrets ..."
		export "${var}"="$(pwgen --capitalize --numerals --secure -1 "${EP_PWGEN_LENGTH}")"
		install --mode=0400 /dev/null "${secrets}"
		echo -n "$(eval echo "\$${var}")" > "${secrets}"
	else
		log "Importing ${var} from environment ..."
		echo -n "$(eval echo "\$${var}")" > "${secrets}"
	fi
}
export -f generate_password

# 1 - prefix
# 2 - server cn
function generate_rsakey
{
	ensure_secrets_root

	local prefix="${1,,}"
	local cn="${2:-"${prefix} server"}"

	if [[ -e ${EP_SECRETS_ROOT}/${prefix}ca.crt && -e ${EP_SECRETS_ROOT}/${prefix}.crt && -e ${EP_SECRETS_ROOT}/${prefix}.key ]] ; then
		log "Importing ${prefix}ca.crt, ${prefix}.crt, and ${prefix}.key from secrets ..."
	else
		# Note: Key size must be >= 3072 for "HIGH" security:
		log "Generating ${prefix}ca.crt, ${prefix}.crt, and ${prefix}.key in secrets ..."

		# Even though it should be safe to invoke, let the caller do this for edge cases
		# where the corresponding passphrase should not be stored in $EP_SECRETS_ROOT ...
		# generate_password "${1,,}_rsa"
		local passphrase="$(eval echo "\$${1^^}_RSA_PASSWORD")"

		log "	certificate authority"
		openssl genrsa \
			-out "/dev/shm/${prefix}ca.key" \
			"${EP_RSA_KEY_SIZE}"
		openssl req \
			-days "${EP_VALIDITY_DAYS}" \
			-key "/dev/shm/${prefix}ca.key" \
			-new \
			-nodes \
			-out "${EP_SECRETS_ROOT}/${prefix}ca.crt" \
			-sha256 \
			-subj "/CN=${prefix} certificate authority" \
			-x509

		log "	server certificate ${passphrase:+[protected]}"
		openssl genrsa \
			${passphrase:+--aes256 --passout "pass:${passphrase}"} \
			-out "${EP_SECRETS_ROOT}/${prefix}.key" \
			"${EP_RSA_KEY_SIZE}"
		openssl req \
			${passphrase:+--passin "pass:${passphrase}"} \
			-key "${EP_SECRETS_ROOT}/${prefix}.key" \
			-new \
			-nodes \
			-out "/dev/shm/${prefix}.csr" \
			-sha256 \
			-subj "/CN=${cn}" \
		# Allow calling scripts to stage an extentions file prior to invoking
		[[ ! -e "/dev/shm/${prefix}.ext" ]] && echo "subjectAltName=DNS:localhost,IP:127.0.0.1" > "/dev/shm/${prefix}.ext"
		openssl x509 \
			-CA "${EP_SECRETS_ROOT}/${prefix}ca.crt" \
			-CAkey "/dev/shm/${prefix}ca.key" \
			-CAcreateserial \
			-days "${EP_VALIDITY_DAYS}" \
			-extfile "/dev/shm/${prefix}.ext" \
			-in "/dev/shm/${prefix}.csr" \
			-out "${EP_SECRETS_ROOT}/${prefix}.crt" \
			-req \
			-sha256

		# Delete the CA key as we do not take responsibility for extended PKI functions!
		rm --force /dev/shm/"${prefix}"{ca.key,.csr,.ext} "${EP_SECRETS_ROOT}/${prefix}ca.srl"

	fi
	[[ -n "$(getent group ssl-cert)" ]] && group=ssl-cert || group=root
	install --group="${group}" --mode=0640 --owner=root "${EP_SECRETS_ROOT}/${prefix}.key" /etc/ssl/private/
	install --group=root --mode=0644 --owner=root "${EP_SECRETS_ROOT}/${prefix}"{,ca}.crt /etc/ssl/certs/
}
export -f generate_rsakey

#1 - user
function generate_sshkey
{
	ensure_secrets_root

	# Note: ssh-keygen -f id_rsa -y > id_rsa.pub
	local key="id_${EP_SSH_KEY_TYPE,,}.${1,,}"
	local secrets="${EP_SECRETS_ROOT}/${key}"
	local userkey="$(eval echo ~"${1,,}")/.ssh/id_${EP_SSH_KEY_TYPE,,}"

	mkdir --parents "$(dirname "${userkey}")"

	if [[ -e "${secrets}" ]] ; then
		log "Importing ${key} from secrets ..."
		ln --force --symbolic "${secrets}" "${userkey}"
	elif [[ ! -e "${userkey}"  ]] ; then
		# Even though it should be safe to invoke, let the caller do this for edge cases
		# where the corresponding passphrase should not be stored in $EP_SECRETS_ROOT ...
		# generate_password "${1,,}_ssh"
		local passphrase="$(eval echo "\$${1^^}_SSH_PASSWORD")"

		log "Generating ${key} in secrets ${passphrase:+[protected]} ..."
		ssh-keygen -b "${EP_SSH_KEY_SIZE}" -f "${secrets}" -t "${EP_SSH_KEY_TYPE}" -N "${passphrase}"
		ln --symbolic "${secrets}" "${userkey}"
	else
		log "Importing ${key} from container ..."
		install --mode=0400 "${userkey}" "${secrets}"
		ln --force --symbolic "${secrets}" "${userkey}"
	fi
}
export -f generate_sshkey

# 1 - template / defaults prefix
# 2 - target
# 3 - shell format (optional)
function render_template
{
	log "Generating: $(basename "${2}") ..."
	if [[ -f "${1}.defaults" ]] ; then
		while IFS="=" read -r key value
		do
			eval "export ${key}=\${${key}:=${value}}"
			log "	${key}=${!key}"
		done < "${1}.defaults"
	fi

	if [[ -z "${3}" ]] ; then
		envsubst < "${1}.template" > "${2}"
	else
		envsubst "${3}" < "${1}.template" > "${2}"
	fi
}
export -f render_template

