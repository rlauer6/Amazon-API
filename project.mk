#-*- mode: makefile; -*-

BUILD_DIR ?= $(shell pwd)

BOTOCORE_PATH  = $(BUILD_DIR)/botocore
BOTOCORE_STATE = $(BUILD_DIR)/.botocore.state
BOTOCORE_REPO  = https://github.com/boto/botocore.git

BUILD_BOTO_SERVICES = $(BUILD_DIR)/bin/build-boto-services
CREATE_MODULE_NAMES = $(BUILD_DIR)/bin/amzn-api-module-names

CPAN_DIST_MAKER=cpan-maker
DEPS += services.api botocore-metadata.api

$(BUILD_BOTO_SERVICES):
	cd $(BUILD_DIR); \
	$(MAKE)

$(CREATE_MODULE_NAMES):
	cd $(BUILD_DIR); \
	$(MAKE)

PERL5LIBDIR = $(BUILD_DIR)/lib

$(BOTOCORE_STATE): | $(BOTOCORE_PATH)
	remote_hash=$$(git ls-remote $(BOTOCORE_REPO) HEAD | awk '{print $$1}'); \
	if [ ! -f $(BOTOCORE_STATE) ] || [ "$$remote_hash" != "$$(cat $(BOTOCORE_STATE))" ]; then \
	  echo "$$remote_hash" > $(BOTOCORE_STATE); \
	  cd $(BOTOCORE_PATH) && git pull; \
	fi

# The directory target handles the initial clone
$(BOTOCORE_PATH):
	mkdir -p $@; \
	git clone --depth=1 $(BOTOCORE_REPO) $@
	cd $@

botocore-metadata.api: module_names.json $(BOTOCORE_STATE) $(CREATE_MODULE_NAMES) | $(BOTOCORE_PATH)
	PERL5LIB=$(PERL5LIB):$(PERL5LIBDIR) $(CREATE_MODULE_NAMES) -b $(BOTOCORE_PATH) create

# services.api only runs if missing or if the botocore dir is newer
services.api: \
    $(BOTOCORE_STATE) \
    $(BUILD_BOTO_SERVICES) | $(BOTOCORE_PATH)
	PERL5LIB=$(PERL5LIB):$(PERL5LIBDIR) $(BUILD_BOTO_SERVICES) -p $(BOTOCORE_PATH) -o $@

# update-botocore now ensures the directory exists first
.PHONY: update-botocore
update-botocore: $(BOTOCORE_PATH)
	cd $(BOTOCORE_PATH) && git pull

workdir/requires: requires.cpan-dist | workdir
	cp $< $@

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
	$(CPAN_DIST_MAKER) $$PROJECT_ROOT \
	  $$REQUIRES \
	  $$DRYRUN \
	  $$NOVERSION \
	  $$NOCLEANUP \
	  $$DEBUG -b $$(basename $<) || echo "$$?"; \
	cp $$(ls -1 *.tar.gz) ../
	rm -rf workdir

workdir/service.api: $(BOTOCORE_PATH) botocore-metadata.api | workdir
	$(NO_ECHO)if [[ -z "$(SERVICE)" ]]; then \
	  echo >&2 "ERROR: no SERVICE specified. usage SERVICE=service\n"; \
	  exit 1; \
	fi; \
	service="$(SERVICE)"; \
	module_name="$$(amazon-api module-name $$service)"; \
	echo $$service > workdir/service; \
	echo $$module_name > workdir/module; \
	service_found="$$(find $(BOTOCORE_PATH)/botocore/data -mindepth 1 -maxdepth 1 -type d -name $$service 2>/dev/null)"; \
	if [[ -z "$$service_found" ]]; then \
	  echo >&2 "ERROR: no such service $$service"; \
	  exit 1; \
	fi; \
	cd workdir; \
	mkdir -p lib; \
	if test -n "$$TIDY"; then \
	  TIDY="--tidy"; \
	fi; \
	for a in stub shapes; do \
	  echo "creating...$$a"; \
	  amazon-api $$TIDY -b $(BOTOCORE_PATH) --pod -s "$$service" -m "$$module_name" -o lib "create-$$a"; \
	done; \
	module_path="$$(echo lib/Amazon/API/$${module_name}.pm | sed -e 's/::/\//g;')"; \
	service_date=$$(build-boto-services -p $(BOTOCORE_PATH) list $$service | jq -r .date); \
        service_date="$${service_date//-/.}"; \
	sed -e 's/[@]SERVICE_VERSION[@]/'$$service_date'/' $$module_path > $${module_path}.tmp; \
	mv $${module_path}.tmp $${module_path}; \
	for a in $$(find lib -name '*.pm'); do \
	  temp="$${a%.pm}"; \
	  podextract -i $$a -o $$a.tmp -p "$${temp}.pod"; \
	  mv $$a.tmp $$a; \
	done; \
	cp "lib/$${module_name}.api" $$(basename $@)

BOTOCORE_BASE := $(BOTOCORE_PATH)/botocore/data

.PHONY: all-services
all-services: xml.services json.services rest-json.services query.services

.PHONY: xml.services
xml.services: 
	grep -ri '"protocol":' $(BOTOCORE_BASE) | grep 'xml' | \
	  cut -f 4 -d '/' | sort -u > $@

.PHONY: json.services
json.services:
	grep -ri '"protocol":' $(BOTOCORE_BASE) | grep '"json"' | \
	  cut -f 4 -d '/' | sort -u > $@

.PHONY: rest-json.services
rest-json.services:
	grep -ri '"protocol":' $(BOTOCORE_BASE) | grep '"rest-json"' | \
	  cut -f 4 -d '/' | sort -u > $@

.PHONY: query.services
query.services:
	grep -ri '"protocol":' $(BOTOCORE_BASE) | grep 'query' | \
	  cut -f 4 -d '/' | sort -u > $@

workdir:
	mkdir -p workdir

clean-local::
	rm -rf workdir

define script
require Text::ASCIITable;
use JSON;

my $s = <>;

$s = JSON->new->decode($s);

my $t = Text::ASCIITable->new({ headingText => "Amazon Services"});

$t->setCols("Service", "Description");

foreach (sort keys %{$s}) {
 $t->addRow($_, $s->{$_});
}

print $t;
endef

export scriptlet = $(value script)

list-services: service-listing.json
	$(NO_ECHO)if perl -MText::ASCIITable -e 1 2>/dev/null; then \
	  perl -0 -e "$$scriptlet" $<; \
	else \
	  jq --sort-keys . service-listing.json; \
	fi

service-listing.json: botocore
	$(NO_ECHO)JQ=$$(command -v jq); \
	if test -z "$$JQ"; then \
	 >&2 echo "ERROR: no jq found...install jq"; \
	 false; \
	fi; \
	listing=$$(mktemp); \
	for a in $$(find botocore/botocore/data -mindepth 1 -maxdepth 1 -type d); do \
	  echo "$$(basename $$a),$$($$JQ -r .metadata.serviceFullName $$a/$$(ls -1 $$a | sort | tail -1)/service*)" >>$$listing; \
	done; \
	perl -MJSON::XS -e 'while(<>) { chomp; ($$k,$$v) = split /,/,$$_; $$listing{$$k} = $$v; }; print JSON::XS->new->pretty->encode(\%listing);' $$listing >$@; \
	rm $$listing;

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
	    EMAIL=$$($$GIT config --global --get user.email); \
	  else \
	    EMAIL="rclauer@gmail.com"; \
	  fi; \
	fi; \
	if [[ -z "$$FULLNAME" ]]; then \
	  if [[ -n "$$GIT" ]]; then \
	    FULLNAME=$$($$GIT config --global --get user.name); \
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
	cpanm -n -v -l $(HOME) $<
