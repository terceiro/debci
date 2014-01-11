generated = \
	public/doc/index.html \
	public/jquery.js \
	public/jquery.flot.js \
	public/jquery.flot.stack.js \
	public/jquery.flot.time.js

all: $(generated)

public/doc/index.html: README.md
	mkdir -p public/doc
	pandoc -f markdown -t html5 -s -o $@ $<

public/jquery.js:
	ln -s /usr/share/javascript/jquery/jquery.min.js $@

public/jquery.flot.js:
	ln -s /usr/share/javascript/jquery-flot/jquery.flot.min.js $@

public/jquery.flot.stack.js:
	ln -s /usr/share/javascript/jquery-flot/jquery.flot.stack.min.js $@

public/jquery.flot.time.js:
	ln -s /usr/share/javascript/jquery-flot/jquery.flot.time.min.js $@

publish: all
	rsync -avp --delete --copy-links public/ dep8.debian.net:/srv/dep8.debian.net/htdocs/

.PHONY: tags

tags:
	ctags -R --exclude=chroots .

clean:
	$(RM) $(generated) tags
