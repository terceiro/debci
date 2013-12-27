doc.html: README.md
	pandoc -f markdown -t html5 -s -o $@ $<

clean:
	$(RM) doc.html
