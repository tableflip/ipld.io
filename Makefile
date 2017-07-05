DOMAIN="ipld.io"

IPFSLOCAL="http://localhost:8080/ipfs/"
IPFSGATEWAY="https://ipfs.io/ipfs/"
NPM=npm
NPMBIN=./node_modules/.bin
OUTPUTDIR=public
PIDFILE=dev.pid

build: clean install lint css js minify
	@hugo && \
	echo "" && \
	echo "Site built out to ./public dir"

help:
	@echo 'Makefile for a filecoin.io, a hugo built static site.                                                          '
	@echo '                                                                                                          '
	@echo 'Usage:                                                                                                    '
	@echo '   make                                Build the optimised site to ./$(OUTPUTDIR)                         '
	@echo '   make serve                          Preview the production ready site at http://localhost:1313         '
	@echo '   make lint                           Check your JS and CSS are ok                                       '
	@echo '   make js                             Copy the *.js to ./static/js                                 '
	@echo '   make css                            Compile the *.css to ./static/css                                 '
	@echo '   make minify                         Optimise all the things!                                           '
	@echo '   make dev                            Start a hot-reloding dev server on http://localhost:1313           '
	@echo '   make dev-stop                       Stop the dev server                                                '
	@echo '   make deploy                         Add the website to your local IPFS node                            '
	@echo '   make publish-to-domain              Update $(DOMAIN) DNS record to the ipfs hash from the last deploy  '
	@echo '   make clean                          remove the generated files                                         '
	@echo '                                                                                                          '

serve: install lint js css minify
	hugo server

node_modules:
	$(NPM) i

install: node_modules
	[ -d static/css ] || mkdir -p static/css && \
	[ -d static/js ] || mkdir -p static/js

lint: install
	$(NPMBIN)/standard layouts && $(NPMBIN)/lessc --lint layouts/less/*

css: install
	$(NPMBIN)/lessc --clean-css --autoprefix layouts/less/main.less static/css/main.css

js: install
	rsync layouts/js/ static/js

minify: install minify-js minify-img

minify-js: install
	find static/js -name '*.js' -exec $(NPMBIN)/uglifyjs {} --compress --output {} \;

minify-img: install
	find static/img -type d -exec $(NPMBIN)/imagemin {}/* --out-dir={} \;

dev: install css js
	[ ! -f $(PIDFILE) ] || rm $(PIDFILE) ; \
	touch $(PIDFILE) ; \
	$(NPMBIN)/nodemon --watch layouts/css --exec "$(NPMBIN)/lessc --clean-css --autoprefix layouts/less/main.less static/css/main.css" & echo $$! >> $(PIDFILE) ; \
	hugo server -w & echo $$! >> $(PIDFILE)

dev-stop:
	touch $(PIDFILE) ; \
	[ -z "`(cat $(PIDFILE))`" ] || kill `(cat $(PIDFILE))` ; \
	rm $(PIDFILE)

deploy:
	ipfs swarm peers >/dev/null || (echo "ipfs daemon must be online to publish" && exit 1)
	ipfs add -r -q $(OUTPUTDIR) | tail -n1 >versions/current
	cat versions/current >>versions/history
	@export hash=`cat versions/current`; \
		echo ""; \
		echo "published website:"; \
		echo "- $(IPFSLOCAL)$$hash"; \
		echo "- $(IPFSGATEWAY)$$hash"; \
		echo ""; \
		echo "next steps:"; \
		echo "- ipfs pin add -r /ipfs/$$hash"; \
		echo "- make publish-to-domain"; \

publish-to-domain: auth.token versions/current
	DNSIMPLE_TOKEN=$(shell cat auth.token) \
	./dnslink.sh $(DOMAIN) $(shell cat versions/current)

clean:
	[ ! -d $(OUTPUTDIR) ] || rm -rf $(OUTPUTDIR) && \
	[ ! -d static/css ] || rm -rf static/css/*.css && \
	[ ! -d static/js ] || rm -rf static/js/*.js

.PHONY: build help install lint css js minify minify-js minify-img  dev stopdev deploy publish-to-domain clean
