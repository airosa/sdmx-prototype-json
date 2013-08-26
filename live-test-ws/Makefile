TESTS = $(shell find test -wholename "*spec.coffee")

install:
	@test `which npm` || echo 'You need to have npm installed'
	@npm install

test: release
	@./node_modules/mocha/bin/mocha $(TESTS)

release:
	@rm -f *.js
	@coffee -c *.coffee

.PHONY: install test release
