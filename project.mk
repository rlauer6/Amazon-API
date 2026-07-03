#-*- mode: makefile; -*-

BUILD_DIR ?= $(shell pwd)

BOTOCORE_PATH  = $(BUILD_DIR)/botocore
BOTOCORE_STATE = $(BUILD_DIR)/.botocore.state
BOTOCORE_REPO  = https://github.com/boto/botocore.git

BUILD_BOTO_SERVICES = $(BUILD_DIR)/bin/build-boto-services

CPAN_DIST_MAKER=make-cpan-dist.pl
DEPS += services.api

$(BUILD_BOTO_SERVICES):
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

.PHONY: cpan
cpan: workdir/buildspec-api.yml api workdir/requires | workdir
	$(NO_ECHO)cd workdir; \
	service=$$(cat service); \
	module_name=$$(cat module); \
	test -n "$$DEBUG" && set -x; \
	test -n "$$DEBUG" && DEBUG="--debug"; \
	test -e requires && REQUIRES="-r requires"; \
	test -n "$(NOCLEANUP)" && NOCLEANUP="--no-cleanup"; \
	test -n "$(DRYRUN)" && DRYRUN="--dryrun"; \
	test -n "$(SCANDEPS)" && SCANDEPS="-s"; \
	test -n "$(NOVERSION)" && NOVERSION="-n"; \
	REAL_PATH=$$(realpath .); \
	PROJECT_ROOT="--project-root $$REAL_PATH"; \
	$(CPAN_DIST_MAKER) $$PROJECT_ROOT \
	  $$REQUIRES \
	  $$DRYRUN \
	  $$SCANDEPS \
	  $$NOVERSION \
	  $$NOCLEANUP \
	  $$DEBUG -b $$(basename $<) || echo "$$?"
	rm -rf workdir

api: $(BOTOCORE_PATH) workdir/service workdir/module | workdir
	$(NO_ECHO)cd workdir; \
	boto_service=$$(cat service); \
	module_name=$$(cat module); \
	mkdir -p lib; \
	if test -n "$$TIDY"; then \
	  TIDY="--tidy"; \
	fi; \
	for a in stub shapes; do \
	  echo "creating...$$a"; \
	  amazon-api $$TIDY -b $(BOTOCORE_PATH) -s $$boto_service -m $$module_name -o lib create-$$a; \
	done; \
	module_path=$$(echo "lib/Amazon/API/$${module_name}.pm" | sed -e 's/::/\//g;'); \
	echo $$module_path; \
	service_date=$$(build-boto-services -p $(BOTOCORE_PATH) list $$boto_service | jq -r .date); \
        service_date="$${service_date//-/.}"; \
	echo $$service_date; \
	sed -e 's/[@]SERVICE_VERSION[@]/'$$service_date'/' $$module_path > $${module_path}.tmp; \
	mv $${module_path}.tmp $${module_path}; \
	for a in $$(find lib -name '*.pm'); do \
	  temp="$${a%.pm}"; \
	  podextract -i $$a -o $$a.tmp -p "$${temp}.pod"; \
	  mv $$a.tmp $$a; \
	done

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

workdir/service: | workdir
	$(NO_ECHO)if [[ -n "$(SERVICE)" ]]; then \
	  echo "$(SERVICE)" | tr [A-Z] [a-z] > $@; \
	elif [[ -n "$(MODULE_ALIAS)" ]]; then \
	  echo "$(MODULE_ALIAS)" | tr [A-Z] [a-z] > $@; \
	else \
	  echo "ERROR: usage: make MODULE_ALIAS=module or SERVICE=service"; \
	  false; \
	fi
	service=$$(cat $@); \
	service_found="$$(find botocore/botocore/data -mindepth 1 -maxdepth 1 -type d -name $$service 2>/dev/null)"; \
	if [[ -z "$$service_found" ]]; then \
	  echo >&2 "ERROR: no such service $$service"; \
	  rm -f $@ module && exit 1; \
	fi

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

workdir/module: workdir/service | workdir
	$(NO_ECHO)if test -z "$(MODULE_ALIAS)"; then \
	  echo "$(SERVICE)" | tr [a-z] [A-Z] > $@; \
	else \
	  echo "$(MODULE_ALIAS)" > $@; \
	fi

workdir/buildspec-api.yml: buildspec-api.yml.in | workdir
	$(NO_ECHO)test -d workdir || mkdir -p workdir; \
	service=$$(cat service); \
	GIT=$$(command -v git || true); \
	module_name=$$(cat module); \
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
	tree workdir

llm-release-notes:
	$(NO_ECHO)$(MAKE) release-notes; \
	if [[ -e "release-$(VERSION).diffs" ]]; then \
	  echo bootstrapper release-notes; \
	fi
