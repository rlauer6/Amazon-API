#-*- mode: makefile; -*-

BUILD_DIR           ?= $(shell pwd)
AMAZON_API          = $(BUILD_DIR)/bin/amzn-api

########################################################################
# !! IMPORTANT !!
########################################################################
# Should 'botocore-metata.api' (fresh checkout) is missing, it will
# get regenerated for Amazon-API we create a version of that file
# without the metadata otherwise it would be 15M in size. For
# Amazon-API-Help we want that metadata as part of the project.
METADATA  = --no-metadata
########################################################################

DEPS += services.api botocore-metadata.api

$(AMAZON_API):
	$(NO_ECHO)cd $(BUILD_DIR); \
	$(MAKE)

PERL5LIBDIR = $(BUILD_DIR)/lib

CLEANFILES += $(BUILD_DIR)/botocore-version.json .botocore.state

include botocore.mk

workdir:
	$(NO_ECHO)mkdir -p workdir

.PHONY: cpan-dist
cpan-dist: workdir/buildspec-api.yml workdir/requires | workdir ## create a CPAN distribution for an AWS API (make SERVICE=route53 MODULE_ALIAS=Route53)
	$(NO_ECHO)cd workdir; \
	echo "Creating Amazon::API::$$(cat module)..."; \
	test -n "$$DEBUG" && set -x; \
	test -n "$$DEBUG" && DEBUG="--debug"; \
	test -e requires && REQUIRES="-r requires"; \
	test -n "$(NOCLEANUP)" && NOCLEANUP="--no-cleanup"; \
	test -n "$(DRYRUN)" && DRYRUN="--dryrun"; \
	test -n "$(NOVERSION)" && NOVERSION="-n"; \
	REAL_PATH=$$(realpath .); \
	PROJECT_ROOT="--project-root $$REAL_PATH"; \
	$(CPAN_MAKER) $$PROJECT_ROOT \
	  $$REQUIRES \
	  $$DRYRUN \
	  $$NOVERSION \
	  $$NOCLEANUP \
	  $$DEBUG -b $$(basename $<) || echo "$$?"; \
	cp $$(ls -1 *.tar.gz) ../
	NO_CLEANUP="$${NO_CLEANUP:-}"; \
	if [[ -z "$$NO_CLEANUP" ]]; then \
	  rm -rf workdir; \
	fi

workdir/service.api: \
    $(BOTOCORE_PATH) \
    $(AMAZON_API) \
    botocore-metadata.api \
    botocore-version.json | workdir
	$(NO_ECHO)if [[ -z "$(SERVICE)" ]]; then \
	  echo >&2 "ERROR: no SERVICE specified. usage SERVICE=service\n"; \
	  exit 1; \
	fi; \
	service="$(SERVICE)"; \
	module_name="$$(PERL5LIB=lib:$$PERL5LIB $(AMAZON_API) get-module-name $$service)"; \
	echo $$service > workdir/service; \
	echo $$module_name > workdir/module; \
	service_found="$$(find $(BOTOCORE_PATH)/botocore/data -mindepth 1 -maxdepth 1 -type d -name $$service 2>/dev/null)"; \
	if [[ -z "$$service_found" ]]; then \
	  echo >&2 "ERROR: no such service $$service"; \
	  exit 1; \
	fi; \
	cp botocore-version.json workdir/; \
	cd workdir; \
	mkdir -p lib; \
	PERL5LIB=../lib:$$PERL5LIB $(AMAZON_API) -b $(BOTOCORE_PATH)  -s "$$service" -m "$$module_name" -o lib create-stub; \
	cp "lib/Amazon/API/$${module_name}.api.gz" $$(basename $@)

workdir/buildspec-api.yml: buildspec-api.yml.in workdir/service.api | workdir
	$(NO_ECHO)service=$$(cat workdir/service 2>/dev/null || true); \
	GIT=$$(command -v git || true); \
	module_name=$$(cat workdir/module 2> /dev/null || true); \
	if [[ -z "$$service" ]] && [[ -z "$$module_name" ]]; then \
	  echo "no SERVICE or MODULE_ALIAS specified - make SERVICE=ecr"; \
	  false; \
	fi; \
	if [[ -z "$$EMAIL" ]]; then \
	  if [[ -n "$$GIT" ]]; then \
	    EMAIL=$$($$GIT config --global --get user.email || true); \
	  else \
	    EMAIL="rclauer@gmail.com"; \
	  fi; \
	fi; \
	if [[ -z "$$FULLNAME" ]]; then \
	  if [[ -n "$$GIT" ]]; then \
	    FULLNAME=$$($$GIT config --global --get user.name || true); \
	  else \
	    FULLNAME='aws-api-autobuilder'; \
	  fi; \
	fi; \
	DATE=$$(date +%Y-%m-%d); \
	sed \
	-e "s/@date@/$$DATE/g" \
	-e "s/@service@/$$module_name/g" \
	-e "s/@email@/$$EMAIL/g" \
	-e "s/@name@/$$FULLNAME/g" $< > $@

.PHONY: install
install: $(TARBALL)
	$(NO_ECHO)cpanm -n -v -l $(HOME) $<

# TODO: relocation module-names.json to share/
clean-local::
	$(NO_ECHO)rm -rf workdir *.sig
