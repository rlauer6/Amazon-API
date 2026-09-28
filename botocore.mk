BOTOCORE_PATH         := $(BUILD_DIR)/botocore
BOTOCORE_STATE        := $(BUILD_DIR)/.botocore.state
BOTOCORE_REPO         := https://github.com/boto/botocore.git
BOTOCORE_BASE         := $(BOTOCORE_PATH)/botocore/data
BOTOCORE_VERSION_FILE := BOTOCORE_VERSION

TARBALL_ORDER_ONLY_PREREQS += check-botocore-version

########################################################################
# Botocore is pinned by RELEASE TAG.
#
# BOTOCORE_VERSION contains the release tag used to generate Amazon::API
# metadata and service classes. Normal builds never advance that pin.
#
# The checked-out tag and commit are recorded in botocore-version.json
# and exposed through Amazon::API::BuildInfo for downstream provenance.
#
# Use:
#
#   make update-botocore
#
# to explicitly advance BOTOCORE_VERSION to the latest Botocore release.
#
# Distribution builds check for a newer Botocore release and warn, but do
# not modify the pin.
########################################################################

########################################################################
# Ensure that the Botocore checkout matches BOTOCORE_VERSION.
#
# This target is deliberately phony so that a manually changed checkout
# is corrected even when BOTOCORE_VERSION itself has not changed.
########################################################################

.PHONY: botocore-checkout
botocore-checkout: $(BOTOCORE_VERSION_FILE) | $(BOTOCORE_PATH)
	$(NO_ECHO)pinned=$$(cat $(BOTOCORE_VERSION_FILE)); \
	test -n "$$pinned" || { \
	  echo "ERROR: $(BOTOCORE_VERSION_FILE) is empty" >&2; \
	  exit 1; \
	}; \
	current=$$(cd $(BOTOCORE_PATH) && \
	  git describe --tags --exact-match HEAD 2>/dev/null || true); \
	if [[ "$$current" != "$$pinned" ]]; then \
	  echo "Checking out pinned Botocore $$pinned (was $${current:-untagged})"; \
	  cd $(BOTOCORE_PATH); \
	  if ! git rev-parse --verify --quiet "refs/tags/$$pinned" >/dev/null; then \
	    git fetch --quiet --depth=1 origin \
	      "refs/tags/$$pinned:refs/tags/$$pinned"; \
	  fi; \
	  git checkout --quiet --detach "$$pinned"; \
	fi

########################################################################
# Record the commit corresponding to the pinned checkout.
#
# The file is only rewritten when HEAD changes so downstream targets do
# not rebuild merely because botocore-checkout was examined.
########################################################################

$(BOTOCORE_STATE): botocore-checkout
	$(NO_ECHO)local=$$(cd $(BOTOCORE_PATH) && git rev-parse HEAD); \
	if [[ ! -e $@ ]] || [[ "$$local" != "$$(cat $@)" ]]; then \
	  echo "$$local" > $@; \
	fi

########################################################################
# Warn when the upstream Botocore release has advanced.
#
# This target never changes the checkout or BOTOCORE_VERSION and does not
# fail a distribution build merely because GitHub cannot be reached.
########################################################################

.PHONY: check-botocore-version
check-botocore-version:
	$(NO_ECHO)pinned=$$(cat $(BOTOCORE_VERSION_FILE)); \
	latest=$$(git ls-remote --tags --refs --sort=-v:refname \
	  $(BOTOCORE_REPO) 2>/dev/null \
	  | head -1 \
	  | sed 's|.*/||'); \
	if [[ -z "$$latest" ]]; then \
	  echo "WARNING: could not determine latest Botocore release" >&2; \
	elif [[ "$$latest" != "$$pinned" ]]; then \
	  echo "WARNING: newer Botocore release available" >&2; \
	  echo "  pinned: $$pinned" >&2; \
	  echo "  latest: $$latest" >&2; \
	fi

########################################################################
# Explicitly advance the Botocore pin.
#
# Updating Botocore is a maintainer action. The new release tag is
# written to BOTOCORE_VERSION and all generated build artifacts are then
# removed so the next build is derived from the new pin.
########################################################################

.PHONY: update-botocore
update-botocore:
	$(NO_ECHO)current=$$(cat $(BOTOCORE_VERSION_FILE)); \
	latest=$$(git ls-remote --tags --refs --sort=-v:refname \
	  $(BOTOCORE_REPO) \
	  | head -1 \
	  | sed 's|.*/||'); \
	test -n "$$latest" || { \
	  echo "ERROR: could not determine latest Botocore release" >&2; \
	  exit 1; \
	}; \
	if [[ "$$latest" == "$$current" ]]; then \
	  echo "Botocore $$current is current"; \
	else \
	  printf '%s\n' "$$latest" > $(BOTOCORE_VERSION_FILE); \
	  echo "Updated Botocore $$current -> $$latest"; \
	  $(MAKE) clean; \
	fi

########################################################################
# Bootstrap the Botocore checkout directly at the pinned release.
########################################################################

$(BOTOCORE_PATH):
	$(NO_ECHO)pinned=$$(cat $(BOTOCORE_VERSION_FILE)); \
	test -n "$$pinned" || { \
	  echo "ERROR: $(BOTOCORE_VERSION_FILE) is empty" >&2; \
	  exit 1; \
	}; \
	mkdir -p $(dir $@); \
	git clone --quiet \
	  --branch "$$pinned" \
	  --depth=1 \
	  $(BOTOCORE_REPO) $@

########################################################################
# Botocore artifacts
########################################################################

$(BUILD_DIR)/partitions.json: $(BOTOCORE_STATE) | $(BOTOCORE_PATH)
	$(NO_ECHO)cp $(BOTOCORE_PATH)/botocore/data/partitions.json $@

.PHONY: botocore-version
botocore-version: $(BOTOCORE_STATE) $(BUILD_DIR)/botocore-version.json

$(BUILD_DIR)/botocore-version.json: \
    $(BOTOCORE_STATE) \
    $(BOTOCORE_VERSION_FILE) | $(BOTOCORE_PATH)
	$(NO_ECHO)pinned=$$(cat $(BOTOCORE_VERSION_FILE)); \
	cd $(BOTOCORE_PATH); \
	commit=$$(git rev-parse HEAD); \
	version=$$(git describe --tags --exact-match HEAD 2>/dev/null); \
	test -n "$$version" || { \
	  echo "ERROR: Botocore HEAD $$commit is not on a release tag" >&2; \
	  exit 1; \
	}; \
	test "$$version" = "$$pinned" || { \
	  echo "ERROR: Botocore checkout $$version does not match pinned release $$pinned" >&2; \
	  exit 1; \
	}; \
	printf '{ "version": "%s", "commit": "%s" }\n' \
	  "$$version" "$$commit" > $@

botocore-metadata.api module-names.json &: \
    $(BOTOCORE_STATE) \
    $(AMAZON_API) | local/.build-requires $(BOTOCORE_PATH)
	$(NO_ECHO)PERL5LIB=$(PERL5LIBDIR):$(BUILD_DIR)/local/lib/perl5 \
	  $(AMAZON_API) -b $(BOTOCORE_PATH) \
	  --no-metadata create-module-names

services.api: \
    $(BOTOCORE_STATE) \
    $(BUILD_DIR)/botocore-version.json \
    $(AMAZON_API) | local/.build-requires $(BOTOCORE_PATH)
	$(NO_ECHO)PERL5LIB=$(PERL5LIBDIR):$(BUILD_DIR)/local/lib/perl5 \
	  $(AMAZON_API) -b $(BOTOCORE_PATH) -f $@ create-services
