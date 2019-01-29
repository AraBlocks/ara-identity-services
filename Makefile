CWD = $(shell pwd)
MUSH = ./bin/mush
SOURCES = $(shell find src/ -type f | xargs printf '%s\n')
TARGETS = $(foreach S, $(SOURCES), $(shell echo $(S) | sed -e 's/src/tmp/g'))
INSTALL_TARGETS = $(foreach T, $(TARGETS), $(shell echo $(T) | sed -e 's/tmp\///g'))
UNINSTALL_TARGETS = $(foreach T, $(TARGETS), $(shell echo $(T) | sed -e 's/tmp/_/g'))

HOSTS ?= /etc/hosts

USER ?= $(shell whoami)
HOME ?= $(HOME)
PREFIX ?= /usr/local
ARA_PATH ?= $(PREFIX)/ara
NODE_PATH ?= $(ARA_PATH)/node_modules
NODE_MODULES ?= $(CWD)/node_modules

export USER
export HOME
export PREFIX
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

default: preamable build

preamable:
	@echo
	@echo '## Welcome to Ara Identity Services build tool'
	@echo
	@if ! test -d tmp; then \
	  echo '(i) Preparing to build files for Ara Identity Services'; \
	  echo; \
	fi

build: $(TARGETS) $(NODE_MODULES)
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

install: preamable preinstall $(INSTALL_TARGETS) $(NODE_PATH) $(HOSTS)
	@echo
	@echo '(i) Please run `$ sudo systemctl daemon-reload` to reload systemd unit files'
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
	@cat $(HOSTS).bak | sed 's/127.0.0.68.*resolver.ara.local.*$$//g' > $(HOSTS)
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

.PHONY: $(HOSTS)
$(HOSTS):
	@if `cat $@ | grep '127.0.0.68' >&2>/dev/null`; then \
		if `cat $@ | grep 'resolver.ara.local' >&2>/dev/null`; then \
			echo '(i) "127.0.0.68" already mapped to "resolver.ara.local"'; \
		else \
			echo '(x) "127.0.0.68" already mapped to a different hostname'; \
			exit 1; \
		fi; \
	else \
		echo '(i) Mapping "resolver.ara.local" to 127.0.0.68"'; \
		printf "127.0.0.68\tresolver.ara.local\tresolver\n" >> $@; \
	fi


clean:
	$(call RM, "tmp/")
