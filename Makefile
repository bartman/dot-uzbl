all: help

help:
	@echo "make [target]"
	@echo
	@echo "Targets..."
	@echo
	@echo "  install      - installs the symlinks in $$HOME"
	@echo
	@echo "This script currently only installs one symlink:"
	@echo
	@echo "  .config/uzbl/config -> .uzbl/configs/uzbl.config"
	@echo
	@echo "(the assumption is that you put this repo in $$HOME/.uzbl)"


install:
	ln -fs .uzbl/configs/uzbl.config ~/.config/uzbl
