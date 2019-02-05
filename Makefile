CWD = $(shell pwd)
MUSH = ./bin/mush
SOURCES = $(shell find src/ -type f | xargs printf '%s\n')
TARGETS = $(foreach S, $(SOURCES), $(shell echo $(S) | sed -e 's/src/tmp/g'))
INSTALL_TARGETS = $(foreach T, $(TARGETS), $(shell echo $(T) | sed -e 's/tmp\///g'))
UNINSTALL_TARGETS = $(foreach T, $(TARGETS), $(shell echo $(T) | sed -e 's/tmp/_/g'))

TARGETS += $(wildcard tmp/etc/ara/ssl/*)

HOSTS ?= /etc/hosts

USER ?= $(shell whoami)
HOME ?= $(HOME)
PREFIX ?= /usr/local
ADDRESS ?= 127.0.0.68
ROOT_CA ?= $(HOME)/.local/share/mkcert/rootCA.pem
ARA_PATH ?= $(PREFIX)/ara
NODE_PATH ?= $(ARA_PATH)/node_modules
NODE_MODULES ?= $(CWD)/node_modules

export USER
export HOME
export DEBUG
export PREFIX
export ADDRESS
export ROOT_CA
export ARA_PATH
export NODE_PATH

## Network Node exports from environment
export PASSWORD
export KEYRING
export SECRET

define INSTALL
	@if ! test -d `dirname $(2)`; then mkdir -p "$(2)"; fi
	@printf " INSTALL %s %s\n" $(1) $(2)
	@install -C $(1) $(2) $(3)
endef

define MKDIR
	@printf "   MKDIR %s\n" $(1)
	@mkdir -p $(1)
endef

define RM
	@printf "      RM %s\n" $(1)
	@rm -rf $(1)
endef

define CP
	@printf "      CP %s\n" $(1) $(2)
	@cp -rf $(1) $(2)
endef

default: build

preamable:
	@echo
	@echo '## Welcome to Ara Identity Services build tool'
	@echo "  Please run 'make help' for more information."
	@echo
	@if ! test -d tmp; then \
	  echo '(i) Preparing to build files for Ara Identity Services'; \
	  echo; \
	fi

build: preamable mkcert $(TARGETS) $(NODE_MODULES)
	@echo
	@echo '(i) Please run `$ sudo make install` to install service files'
	@echo

$(TARGETS): $(SOURCES)
	@if test -f "$@"; then \
		printf "* Removing existing target: '%s'\n" $@; \
		rm -f $@; \
	fi
	@mkdir -p "`dirname $@`"
	@src=`echo $@ | sed -e 's/^tmp/src/g'` && \
		printf "* Generating %s and preserving access permissions\n" $$src && \
		cat $$src | { $(MUSH) > $@; } && \
		chmod `stat $$src -c '%a'` $@

.PHONY: mkcert
mkcert:
	@echo "* Generating SSL certificates for: 'resolver.ara.local $(ADDRESS)'"
	$(call MKDIR, "tmp/mkcert")
	$(call MKDIR, "tmp/etc/ara/ssl")
	@echo
	@cd tmp/mkcert && \
		mkcert -install && \
		mkcert $(CERT_DOMAINS) resolver.ara.local $(ADDRESS) localhost ::1 && \
		mv *+*-key.pem ../etc/ara/ssl/resolver.ara.local.key && \
		mv *+*.pem ../etc/ara/ssl/resolver.ara.local.crt
	@rm -rf tmp/mkcert
	@chmod 0755 tmp/etc/ara/ssl/*

install: preamable preinstall install-host $(INSTALL_TARGETS) $(NODE_PATH)
	@echo
	@echo '(i) Please run `$ sudo systemctl daemon-reload` to reload systemd unit files'
	@echo '(i) Please run `$ sudo systemctl restart ara-identity` to restart already running identity services'
	@echo '(i) Please run `$ sudo systemctl start ara-identity` to start identity services'

preinstall:
	@echo '(i) Preparing to install files for Ara Identity Services'
	@echo

preinstall:

uninstall: $(UNINSTALL_TARGETS)
	$(call RM, "/etc/ara")
	$(call RM, $(ARA_PATH))
	@echo '(i) Removing mapping for "resolver.ara.local" in $(HOSTS)'
	@mv $(HOSTS) $(HOSTS).bak
	@cat $(HOSTS).bak | sed '/.*resolver.ara.local.*$$/d' > $(HOSTS)
	@rm -f $(HOSTS).bak

reinstall: uninstall install

$(INSTALL_TARGETS): $(TARGETS)
	$(call MKDIR, "/`dirname $@`")
	$(call INSTALL, "tmp/$@", "/$@")

$(UNINSTALL_TARGETS):
	$(call RM, "`echo $@ | sed -e 's/_//g'`")

$(NODE_PATH): $(NODE_MODULES)
	$(call MKDIR, "`dirname $@`")
	$(call CP, "$^", "$@")

$(NODE_MODULES):
	npm install

.PHONY: install-host
install-host:
	@if `cat $(HOSTS) | grep $(ADDRESS) > /dev/null`; then \
		if `cat $(HOSTS) | grep 'resolver.ara.local' > /dev/null`; then \
			echo '(i) "$(ADDRESS)" already mapped to "resolver.ara.local"'; \
		else \
			echo '(i) Mapping "resolver.ara.local" to $(ADDRESS)"'; \
			printf "$(ADDRESS)\tresolver.ara.local\tresolver\n" >> $(HOSTS); \
		fi; \
	else \
		echo '(i) Mapping "resolver.ara.local" to $(ADDRESS)"'; \
		printf "$(ADDRESS)\tresolver.ara.local\tresolver\n" >> $(HOSTS); \
	fi

clean:
	$(call RM, "tmp/")

help:
	@echo "usage: make [help|build|clean|install|uninstall|reinstall] ...KEY=VALUE"
	@echo ""
	@echo "where the following environment variables are used as templates"
	@echo "to files in the src/ directory. These are used during the 'build',"
	@echo "'install, 'uninstall', and 'reinstall' phases."
	@echo ""
	@echo "## User Environment"
	@echo "export USER=$(USER)"
	@echo "export HOME=$(HOME)"
	@echo "export DEBUG=$(DEBUG)"
	@echo "export PREFIX=$(PREFIX)"
	@echo "export ROOT_CA=$(ROOT_CA)"
	@echo "export ARA_PATH=$(ARA_PATH)"
	@echo "export NODE_PATH=$(NODE_PATH)"
	@echo ""
	@echo "## Network Settings"
	@echo "export ADDRESS=\"$(ADDRESS)\" # Network address the resolver will listen on"
	@echo ""
	@echo "## Network Node exports from environment"
	@echo "export PASSWORD # Ara identity keystore password"
	@echo "export KEYRING=$(KEYRING) # Keyring path or URL"
	@echo "export SECRET=$(SECRET) # Keyring secret phrase"
	@echo ""

