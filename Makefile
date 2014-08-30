all: public/doc/index.html public/doc/js/jquery.js

include links.mk

links.mk: links
	awk '{ print("LINKS +=", $$1); print($$1, ":"); print("\tmkdir -p $$(shell dirname ", $$1, ")"); print("\tln -s", $$2, $$1)}' $^ > $@

all: $(LINKS)

.PHONY: spec check test

checkdeps:
	@if which dpkg-checkbuilddeps >/dev/null; then dpkg-checkbuilddeps -d "$$(grep-dctrl -n -s Depends . debian/control | grep -v '\$$')"; fi

spec:
	rspec --color

functional:
	test/runall.sh

check: checkdeps all spec functionals

test: check

public/doc/index.html: README.md RUBYAPI.md HACKING.md $(shell find lib -name '*.rb')
	$(RM) public/doc/js/jquery.js
	yardoc --markup markdown --output-dir $@ --main README.md lib - $^

public/doc/js/jquery.js:
	mkdir -p $$(dirname $@)
	ln -sf ../../jquery.js public/doc/js/jquery.js

.PHONY: tags

tags:
	ctags -R --exclude=chroots --exclude='public/jquery*' --exclude=public/bootstrap .

clean:
	$(RM) -rf $(generated) tags public/doc links.mk $(LINKS)
