BOTOCORE_PATH  := $(BUILD_DIR)/botocore
BOTOCORE_STATE := $(BUILD_DIR)/.botocore.state
BOTOCORE_REPO  := https://github.com/boto/botocore.git
BOTOCORE_BASE  := $(BOTOCORE_PATH)/botocore/data

########################################################################
# Botocore is tracked by RELEASE TAG, not by master.
#
# The pin exposed via Amazon::API::BuildInfo (and consumed downstream by
# the factory's --branch clone and the signed provenance records) must be
# a real, checkoutable tag. Tracking master left HEAD on untagged commits,
# so botocore-version.json used to fabricate its two fields from two
# independent sources -- 'version' from `git tag | tail -1` (lexical, so
# 1.43.9 outranks 1.43.73) and 'commit' from the .botocore.state cache --
# which drift the moment a tag advances without the cache regenerating.
#
# Now: botocore-pull checks out the latest release tag; both fields of
# botocore-version.json derive from that one checked-out HEAD.
########################################################################

.PHONY: botocore-pull
botocore-pull: | $(BOTOCORE_PATH)                # checkout latest release tag if newer
	$(NO_ECHO)cd $(BOTOCORE_PATH); \
	latest=$$(git ls-remote --tags --refs --sort=-v:refname $(BOTOCORE_REPO) \
	          | head -1 | sed 's|.*/||'); \
	test -n "$$latest" || { echo "ERROR: could not determine latest botocore tag" >&2; exit 1; }; \
	current=$$(git describe --tags --exact-match HEAD 2>/dev/null || true); \
	if [[ "$$latest" != "$$current" ]]; then \
	  echo "Checking out botocore $$latest (was $${current:-untagged})"; \
	  git fetch --quiet --depth=1 origin "refs/tags/$$latest:refs/tags/$$latest"; \
	  git checkout --quiet --detach "$$latest"; \
	fi

$(BOTOCORE_STATE): | botocore-pull               # records HEAD after checkout, write-if-changed
	$(NO_ECHO)local=$$(cd $(BOTOCORE_PATH) && git rev-parse HEAD); \
	if [[ ! -e $@ ]] || [[ "$$local" != "$$(cat $@)" ]]; then echo "$$local" > $@; fi

.PHONY: botocore-version
botocore-version: $(BOTOCORE_STATE) $(BUILD_DIR)/botocore-version.json

$(BUILD_DIR)/botocore-version.json: $(BOTOCORE_STATE) | $(BOTOCORE_PATH)
	$(NO_ECHO)cd $(BOTOCORE_PATH); \
	commit=$$(git rev-parse HEAD); \
	version=$$(git describe --tags --exact-match HEAD 2>/dev/null); \
	test -n "$$version" || { echo "ERROR: botocore HEAD $$commit is not on a release tag" >&2; exit 1; }; \
	printf '{ "version": "%s", "commit": "%s" }\n' "$$version" "$$commit" >$@

# Bootstrap clone: shallow master tip only. botocore-pull immediately
# supersedes it by detaching onto the latest release tag, so tag-selection
# logic lives in exactly one place (botocore-pull).
$(BOTOCORE_PATH):
	$(NO_ECHO)mkdir -p $@; \
	git clone --quiet --branch master --depth=1 $(BOTOCORE_REPO) $@

botocore-metadata.api module-names.json &: \
    $(BOTOCORE_STATE) \
    $(AMAZON_API) | $(BOTOCORE_PATH)
	$(NO_ECHO)PERL5LIB=$(PERL5LIBDIR):$(BUILD_DIR)/local/lib/perl5 \
	  $(AMAZON_API) -b $(BOTOCORE_PATH) --no-metadata create-module-names

# services.api only runs if missing or if the botocore dir is newer
services.api: \
    $(BOTOCORE_STATE) \
    $(BUILD_DIR)/botocore-version.json \
    $(AMAZON_API) | $(BOTOCORE_PATH)
	$(NO_ECHO)PERL5LIB=$(PERL5LIBDIR):$(BUILD_DIR)/local/lib/perl5 \
	  $(AMAZON_API) -b $(BOTOCORE_PATH) -f $@ create-services

# force botocore to the newest release tag (alias for botocore-pull)
.PHONY: update-botocore
update-botocore: botocore-pull

