generated = public/doc/index.html public/jquery.js

all: $(generated)

public/doc/index.html: README.md
	mkdir -p public/doc
	pandoc -f markdown -t html5 -s -o $@ $<

public/jquery.js:
	ln -s /usr/share/javascript/jquery/jquery.min.js $@

publish: all
	rsync -avp --delete --copy-links public/ dep8.debian.net:/srv/dep8.debian.net/htdocs/

clean:
	$(RM) $(generated)
