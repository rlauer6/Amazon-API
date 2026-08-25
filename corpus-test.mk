#-*- mode: makefile; -*-

PROTOCOLS = \
    ec2 \
    rest-json \
    rest-xml \
    query \
    json

INPUT_CORPUS  = $(patsubst %,corpus-test/input/%.json,$(PROTOCOLS))
OUTPUT_CORPUS = $(patsubst %,corpus-test/output/%.json,$(PROTOCOLS))

corpus-test/input:
	mkdir -p $@

corpus-test/output:
	mkdir -p $@

# Pattern rule: Make iterates automatically, $* is the protocol name, $@ is the target file
corpus-test/input/%.json: | $(BOTOCORE_PATH) corpus-test/input
	$(NO_ECHO)cp $(BOTOCORE_PATH)/tests/unit/protocols/input/$*.json $@

corpus-test/output/%.json: | $(BOTOCORE_PATH) corpus-test/output
	$(NO_ECHO)cp $(BOTOCORE_PATH)/tests/unit/protocols/output/$*.json $@

.PHONY: corpus-test
# Added $(INPUT_CORPUS) and $(OUTPUT_CORPUS) as normal prerequisites
corpus-test: $(INPUT_CORPUS) $(OUTPUT_CORPUS)
	cd corpus-test; \
	prove -v t/ 2>&1 | tee test.log

CLEANFILES += corpus-test/test.log $(INPUT_CORPUS) $(OUTPUT_CORPUS)
