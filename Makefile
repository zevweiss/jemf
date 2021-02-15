MYPYFLAGS = \
	--strict \
	--disallow-incomplete-defs \
	--disallow-untyped-defs \
	--no-implicit-optional \
	--show-error-codes \
	--show-error-context \
	--warn-return-any \
	--warn-unreachable \
	--warn-unused-ignores

PYFILES = jemf update-jemf.py

.PHONY: typecheck
typecheck:
	mypy $(MYPYFLAGS) $(PYFILES)

.PHONY: test
test:
	./test.sh

.PHONY: check
check: test typecheck
