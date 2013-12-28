all: doc.html

doc.html: README.md
	pandoc -f markdown -t html5 -s -o $@ $<

upload: all
	rsync -avp --delete --exclude .whitelist --exclude .git ./ dep8.debian.net:/srv/dep8.debian.net/htdocs/

clean:
	$(RM) doc.html
