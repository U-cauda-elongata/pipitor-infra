#!/bin/sh

set -o errexit -o nounset

INSTALL_ROOT=/usr/share/pipitor-env
WORKER=pipitor

ARCH="$(uname -m)"
VENDOR=unknown
OS="$(uname -s | tr '[:upper:]' '[:lower:]')"
ABI=gnu
TRIPLE="${ARCH}${VENDOR:+-${VENDOR}}-${OS}${ABI:+-${ABI}}"

DHALL=1.40.2
DHALL_JSON=1.7.9
PIPITOR=0.3.0-alpha.9
PIPITOR_KEY=C90F234F43B5075A0D96C6D5986E104E7F079F61
WEBHOOK_SERVER=0.1.0

remove_list=

install_packages() {
	if ! ( type apt-get || type yum ) > /dev/null 2>&1; then
		echo "Missing supported package manager (APT or YUM)"
		return 1
	fi

	remove_list="$(
		{
			packages='ca-certificates git gnupg2 jq msmtp nginx systemd'
			packages="${packages} tmux" # Optional
			ephemeral='coreutils m4' # Packages that are only required by this script.

			for pkg in "${@}"; do
				packages="${packages} ${pkg}"
			done

			IFS=' '
			if type apt-get > /dev/null 2>&1; then
				packages="${packages} openssl sqlite3"
				apt-get update
				# shellcheck disable=SC2086
				apt-get install --assume-yes --no-install-recommends ${packages}
				for dep in ${ephemeral}; do
					if ! dpkg-query --status "${dep}" 2> /dev/null | grep --quiet '^Status:.* installed$'
					then
						remove_list="${remove_list:+${remove_list} }${dep}"
					fi
				done
				if [ "${remove_list}" ]; then
					# shellcheck disable=SC2086
					apt-get install --assume-yes --no-install-recommends ${remove_list}
				fi
			elif type yum > /dev/null 2>&1; then
				packages="${packages} openssl11 sqlite"
				if type amazon-linux-extras; then
					amazon-linux-extras enable epel nginx1
					yum clean metadata
				fi
				yum install --assumeyes epel-release
				# shellcheck disable=SC2086
				yum install --assumeyes ${packages}
				for dep in ${ephemeral}; do
					if ! yum list installed "${dep}" > /dev/null 2>&1; then
						remove_list="${remove_list:+${remove_list} }${dep}"
					fi
				done
				if [ "${remove_list}" ]; then
					# shellcheck disable=SC2086
					yum install --assumeyes ${remove_list}
				fi
			fi
		} >&2
		echo "${remove_list}"
	)"
}

remove_packages() (
	if [ "$(echo "${remove_list}" | wc -w)" -ne 0 ]; then
		IFS=' '
		if type apt-get > /dev/null 2>&1; then
			# shellcheck disable=SC2086
        	apt-get purge --assume-yes --auto-remove ${remove_list}
		elif type yum > /dev/null 2>&1; then
			# shellcheck disable=SC2086
			yum autoremove --assumeyes ${remove_list}
		fi
    fi
)

main() (
	prog="${0}"

	if [ "$(id -u)" -ne 0 ]; then
		exec sudo "${prog}" "${@}"
	fi

	user="${SUDO_USER:-${USER}}"
	home="$(eval echo "~${user}")"

	set --
	dhall_json="https://github.com/dhall-lang/dhall-haskell/releases/download/${DHALL}/dhall-json-${DHALL_JSON}-x86_64-linux.tar.bz2"
	dhall_json_sha256=90b2a0da0e30c0637254382c5697a1df75d26d0d6aae1239320f1df74950fe23
	case "${ARCH}-${OS}" in
	# aarch64-linux)
	# 	dhall_json="https://github.com/U-cauda-elongata/dhall-haskell-build/releases/download/${DHALL}/dhall-json-v${DHALL_JSON}-aarch64-linux-gnu.tar.bz2"
	# 	dhall_json_sha256=
	# 	;;
	# arm*-linux)
	# 	dhall_json="https://github.com/U-cauda-elongata/dhall-haskell-build/releases/download/${DHALL}/dhall-json-v${DHALL_JSON}-arm-linux-gnueabihf.tar.bz2"
	# 	dhall_json_sha256=
	# 	;;
	x86_64-linux)
		;;
	*-linux)
		set qemu-user-binfmt
		;;
	*)
		echo "${prog}: warning: Unknown target: ${TRIPLE}"
		;;
	esac

	if [ ! -f "${home}/.ssh/authorized_keys" ]; then
		echo "${prog}: Missing \`~${user}/.ssh/authorized_keys\`"
		exit 1
	fi

	if [ ! -d "${INSTALL_ROOT}" ]; then
		cp -R "$(dirname "${prog}")" "${INSTALL_ROOT}"
		chown -R root:root "${INSTALL_ROOT}"
	fi
	if [ "$(dirname "${prog}")" != "${INSTALL_ROOT}" ]; then
		rm -rf "${INSTALL_ROOT}/credential"
		cp -R "$(dirname "${prog}")/credential" "${INSTALL_ROOT}/credential"
	fi
	cd "${INSTALL_ROOT}"
	git pull

	install_packages "${@}"
	set --

	if ! id "${WORKER}" > /dev/null; then
		echo "${prog}: Creating worker user: ${WORKER}"
		useradd "${WORKER}"
	fi

	worker_home="$(eval echo "~${WORKER}")"

	# Merge `config` and `credential` directories into `staging`.

	mkdir -p staging

	# `*.in` files are processed by `m4` before copying.
	find config credential ! -type d -name '*.in' \
	| sed -E 's!^(config|credential)/!!' \
	| sort \
	| uniq \
	| while read -r f; do
		mkdir -p "$(dirname "staging/${f}")"
		{ cat "config/${f}" "credential/${f}" 2> /dev/null || true; } \
		| m4 > "staging/${f%.in}"
	done

	# Other files are copied as-is.
	find config ! -type d ! -name '*.in' | while read -r f; do
		mkdir -p "$(dirname "staging/${f#config/}")"
		ln -f "$(pwd)/${f}" "staging/${f#config/}"
	done
	find credential ! -type d ! -name '*.in' | while read -r f; do
		mkdir -p "$(dirname "staging/${f#credential/}")"
		ln -f "${f}" "staging/${f#credential/}"
	done

	chown -R "${WORKER}:${WORKER}" staging/worker
	chmod -R u=rwX,g=rX,o= staging/worker

	# Set up `~${WORKER}`.

	if [ ! -f "${worker_home}/.ssh/authorized_keys" ]; then
		install -c -o "${WORKER}" -g "${WORKER}" -m 700 \
			-d "${worker_home}/.ssh"
		install -c -o "${WORKER}" -g "${WORKER}" -m 600 \
			"${home}/.ssh/authorized_keys" \
			"${worker_home}/.ssh/"
	fi

	# Clone `KF_pipitor-resources.git`.
	cd "${worker_home}"
	if [ ! -e pipitor ]; then
		set +o errexit
		git clone --depth=1 --no-tags --sparse \
			'https://github.com/U-cauda-elongata/KF_pipitor-resources.git' pipitor
		s="${?}"
		set -o errexit
		if [ "${s}" -eq 129 ]; then # Unknown switch (presumably `--sparse`)
			git clone --depth=1 --no-tags \
				'https://github.com/U-cauda-elongata/KF_pipitor-resources.git' pipitor
		elif [ "${s}" -ne 0 ]; then
			exit "${s}"
		fi
	fi
	cd "${OLDPWD}"

	# Mirror `staging/worker` into `~${WORKER}`.
	for f in staging/worker/* staging/worker/.*; do
		if [ ! -e "${worker_home}/${f#staging/worker/}" ] || [ -L "${worker_home}/${f#staging/worker/}" ]
		then
			ln -fs "$(pwd)/${f}" "${worker_home}/${f#staging/worker/}"
		fi
	done

	# Install binary distributions.

	tmp="$(mktemp -d)"
	GNUPGHOME="$(mktemp -d)"
	export GNUPGHOME
	cd "${tmp}"

	gpg2 --batch --keyserver hkps://keys.openpgp.org --recv-keys "${PIPITOR_KEY}"

	curl -fsSL -o dhall-json.tar.bz2 "${dhall_json}"
	echo "${dhall_json_sha256} dhall-json.tar.bz2" | sha256sum --strict --check
	tar -C /usr/local -xjf dhall-json.tar.bz2 ./bin/dhall-to-json

	curl -fsSL -o pipitor.tar.gz "https://github.com/tesaguri/pipitor/releases/download/v${PIPITOR}/pipitor-v${PIPITOR}-${TRIPLE}.tar.gz"
	curl -fsSL -o pipitor.tar.gz.asc "https://github.com/tesaguri/pipitor/releases/download/v${PIPITOR}/pipitor-v${PIPITOR}-${TRIPLE}.tar.gz.asc"
	gpg2 --batch --trusted-key "$(echo "${PIPITOR_KEY}" | tail -c 17)" --verify pipitor.tar.gz.asc pipitor.tar.gz
	tar -C /usr/local/bin -xzf pipitor.tar.gz pipitor

	curl -fsSL -o webhook-server.tar.gz "https://github.com/tesaguri/webhook-server/releases/download/v${WEBHOOK_SERVER}/webhook-server-v${WEBHOOK_SERVER}-${TRIPLE}.tar.gz"
	curl -fsSL -o webhook-server.tar.gz.asc "https://github.com/tesaguri/webhook-server/releases/download/v${WEBHOOK_SERVER}/webhook-server-v${WEBHOOK_SERVER}-${TRIPLE}.tar.gz.asc"
	gpg2 --batch --trusted-key "$(echo "${PIPITOR_KEY}" | tail -c 17)" --verify webhook-server.tar.gz.asc webhook-server.tar.gz
	tar -C /usr/local/bin -xzf webhook-server.tar.gz webhook-server

	cd "${OLDPWD}"
	rm -rf "${tmp}" "${GNUPGHOME}"

	find "staging/etc" ! -type d | while read -r f; do
		if [ ! -e "/${f#staging/}" ] || [ -L "/${f#staging/}" ]; then
			mkdir -p "$(dirname "/${f#staging/}")"
			ln -fs "$(pwd)/${f}" "/${f#staging/}"
		fi
	done

	# Set up systemd units.

	for f in staging/systemd.d/*@.service; do
		if [ ! -e "/etc/systemd/system/${f#staging/systemd.d/}" ] || [ -L "${f}" ]; then
			ln -fs "$(pwd)/${f}" /etc/systemd/system/
		fi
	done
	find "$(pwd)/staging/systemd.d" ! -type d ! -name '*@.service' \
		-exec systemctl enable {} +
	systemctl daemon-reload

	remove_packages
)

main "${@}"
