LUA ?= lua
PYTHON ?= python3

.PHONY: test package
test:
	$(LUA) tests/model.lua
	$(LUA) tests/history.lua
	$(LUA) tests/integration.lua
	$(PYTHON) -m unittest discover -s tests -p 'test_package.py'

package:
	$(PYTHON) scripts/package.py
