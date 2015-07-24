all: public/doc/index.html

include links.mk

links.mk: links
	awk '{ print("LINKS +=", $$1); print($$1, ":"); print("\tmkdir -p $$(shell dirname ", $$1, ")"); print("\tln -sf", $$2, $$1)}' $^ > $@

all: $(LINKS)

.PHONY: spec check test

checkdeps:
	@if which dpkg-checkbuilddeps >/dev/null && which grep-dctrl >/dev/null; then dpkg-checkbuilddeps -d "$$(grep-dctrl -n -s Depends . debian/control | grep -v '\$$')"; fi

spec:
	@./test/banner 'Ruby unit tests'
	rspec --color

functional-tests:
	@./test/banner 'Functional tests'
	test/runall.sh
	$(RM) -v test/erl_crash.dump

backends = $(shell ls -1 backends/)
test_backends = $(patsubst %, test-%, $(backends))
.PHONY: $(test_backends)

test-backends: $(test_backends)

$(test_backends): test-% : backends/%/test-package
	@./test/banner "Test backend $*"
	/usr/bin/time ./bin/debci test -b $* test/fake-package/

check: all check-ui-and-docs spec functional-tests

check-ui-and-docs: all
	test -d public/doc
	test -f public/doc/index.html
	test -L public/doc/js/jquery.js -a -f public/doc/js/jquery.js
	test -L public/jquery.js -a -f public/jquery.js
	test -L public/bootstrap

test: check

public/doc/index.html public/doc/jq/jquery.js: README.md MAINTAINERS.md INSTALL.md RUBYAPI.md HACKING.md $(shell find lib -name '*.rb')
	$(RM) public/doc/js/jquery.js
	yardoc --markup markdown --output-dir public/doc --main README.md lib - $^
	ln -sf ../../jquery.js public/doc/js/jquery.js

.PHONY: tags

tags:
	ctags -R --exclude=data --exclude=chroots --exclude='public/jquery*' --exclude=public/bootstrap .

clean:
	$(RM) -rf $(generated) tags public/doc links.mk $(LINKS)
