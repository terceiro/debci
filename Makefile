generated = \
	public/doc/index.html \
	public/jquery.js \
	public/jquery.flot.js \
	public/jquery.flot.stack.js \
	public/jquery.flot.time.js

all: $(generated) doc

.PHONY: spec check test

spec:
	rspec --color

check: spec
	sh test/runall.sh

test: check

doc: $(shell find lib -name '*.rb') RUBYAPI.md HACKING.md
	yardoc --markup markdown --output-dir $@ --main RUBYAPI.md lib - HACKING.md

public/doc/index.html: README.md
	mkdir -p public/doc
	pandoc --from markdown --to html5 --standalone --template public/doc-template.html --table-of-contents --toc-depth=1 -o $@ $<

public/doc/index.html: public/doc-template.html

public/jquery.js:
	ln -s /usr/share/javascript/jquery/jquery.min.js $@

public/jquery.flot.js:
	ln -s /usr/share/javascript/jquery-flot/jquery.flot.min.js $@

public/jquery.flot.stack.js:
	ln -s /usr/share/javascript/jquery-flot/jquery.flot.stack.min.js $@

public/jquery.flot.time.js:
	ln -s /usr/share/javascript/jquery-flot/jquery.flot.time.min.js $@

.PHONY: tags

tags:
	ctags -R --exclude=chroots --exclude='public/jquery*' --exclude=public/bootstrap .

clean:
	$(RM) $(generated) tags
	$(RM) -rf doc
