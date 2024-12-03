# This Makefile helps automate our build process

# Where to install the binary
PREFIX = /usr/local

# Default action: build everything
all: build

# Build the binary
build:
	chmod +x src/*.sh
	chmod +x build.sh
	./build.sh

# Install the binary and configs to the system
install:
	install -m 755 bin/docker-setup $(PREFIX)/bin/
	mkdir -p $(PREFIX)/share/docker-setup
	cp -r bin/config $(PREFIX)/share/docker-setup/

# Clean up build files
clean:
	rm -rf bin/*
	rm -f docker-setup.tar.gz

# Tell Make these aren't actual files
.PHONY: all build install clean