.DEFAULT_GOAL := help

PREFIX ?= $(HOME)/.local
CODEX_NETJAIL_ALLOW ?=
CODEX_NETJAIL_OLLAMA ?= 127.0.0.1:11434
CODEX_NETJAIL_CMD ?= codex --oss --local-provider ollama
CODEX_NETJAIL_LOG ?= $(or $(XDG_STATE_HOME),$(HOME)/.local/state)/codex-netjail/connect.log

.PHONY: help install uninstall check log

help:
	@echo "Targets:"
	@echo "  install    link codex-netjail into $(PREFIX)/bin"
	@echo "  uninstall  remove that link"
	@echo "  check      prove the namespace has no way out except the allowlist"
	@echo "  log        show the last proxy decisions"
	@echo ""
	@echo "Variables (environment overrides the script the same way):"
	@echo "  PREFIX               = $(PREFIX)"
	@echo "  CODEX_NETJAIL_ALLOW  = $(CODEX_NETJAIL_ALLOW)"
	@echo "  CODEX_NETJAIL_OLLAMA = $(CODEX_NETJAIL_OLLAMA)"
	@echo "  CODEX_NETJAIL_CMD    = $(CODEX_NETJAIL_CMD)"
	@echo "  CODEX_NETJAIL_LOG    = $(CODEX_NETJAIL_LOG)"

install:
	mkdir -p $(PREFIX)/bin
	ln -sf $(CURDIR)/codex-netjail $(PREFIX)/bin/codex-netjail

uninstall:
	rm -f $(PREFIX)/bin/codex-netjail

check:
	bash tests/check.sh

log:
	tail -n 30 $(CODEX_NETJAIL_LOG)
