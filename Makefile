all: public/doc

include links.mk

links.mk: links
	awk '{ print("LINKS +=", $$1); print($$1, ":"); print("\tmkdir -p $$(shell dirname ", $$1, ")"); print("\tln -s", $$2, $$1)}' $^ > $@

all: $(LINKS)

.PHONY: spec check test

spec:
	rspec --color

check: spec
	sh test/runall.sh

test: check

public/doc: README.md RUBYAPI.md HACKING.md
	yardoc --markup markdown --output-dir $@ --main README.md lib - $^
	cd public/doc/js && ln -sf ../../jquery.js

public/doc: $(shell find lib -name '*.rb')

.PHONY: tags

tags:
	ctags -R --exclude=chroots --exclude='public/jquery*' --exclude=public/bootstrap .

clean:
	$(RM) -rf $(generated) tags public/doc links.mk $(LINKS)
