PYTHON = python3
VENV = $(CURDIR)/.venv
VENV_PIP = $(VENV)/bin/pip
VENV_PYTHON = $(VENV)/bin/python
VENV_DONE = $(VENV)/.done

$(VENV)/bin/4sq_checkins.py: $(VENV_DONE)
	echo '#!/bin/sh' >$@
	echo 'exec "$(VENV_PYTHON)" "$(CURDIR)/$(notdir $@)" "$$@"' >>$@
	chmod +x $@

.PHONY: venv
venv: $(VENV_DONE)

.PHONY: clean
clean:
	git clean -ffdX

$(VENV_DONE): $(MAKEFILE_LIST) requirements.txt
	$(PYTHON) -m venv --system-site-packages $(VENV)
	$(VENV_PIP) install -r requirements.txt
	touch $@
