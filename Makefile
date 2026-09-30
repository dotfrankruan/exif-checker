# ============================================================================
# ExifChecker Makefile
#
# Common targets:
#   make            (or `make bundle`)  Build a release binary and package it
#                                       as dist/ExifChecker.app
#   make run                            Build the debug binary and launch the
#                                       GUI directly (no .app bundle needed)
#   make test                           Run the unit test suite
#   make install                        Copy dist/ExifChecker.app to /Applications
#   make clean                          Remove all build artifacts
#
# CLI mode (exiftool-style dump to stdout):
#   .build/release/ExifChecker --dump <file> [<file> ...]
#   make dump-heic                      Dump the user's Desktop HEIC sample
#   make dump-mov                       Dump the user's Desktop MOV sample
# ============================================================================

APP_NAME    := ExifChecker
BUILD_DIR   := .build
DIST_DIR    := dist
APP_BUNDLE  := $(DIST_DIR)/$(APP_NAME).app
RELEASE_BIN := $(BUILD_DIR)/release/$(APP_NAME)
DEBUG_BIN   := $(BUILD_DIR)/debug/$(APP_NAME)

# Sample files used by the two convenience targets at the bottom of this
# file. They are NOT bundled: override them to point at your own media, e.g.
#
#     make dump-heic SAMPLE_HEIC=~/Pictures/pic.heic
#
SAMPLE_HEIC ?= $(HOME)/Desktop/sample.heic
SAMPLE_MOV  ?= $(HOME)/Desktop/sample.mov

.PHONY: all build build-debug run test bundle open install dump-heic dump-mov clean

# Default target: produce the distributable .app bundle.
all: bundle

# ---- Building ---------------------------------------------------------------

## Optimized release build.
build:
	swift build -c release

## Fast debug build.
build-debug:
	swift build

# ---- Running ----------------------------------------------------------------

## Build the debug binary and launch the GUI straight from the terminal.
run: build-debug
	$(DEBUG_BIN)

## Package the release build as an .app and open it via LaunchServices.
open: bundle
	open "$(APP_BUNDLE)"

# ---- CLI dump convenience ---------------------------------------------------

## Dump a HEIC/HEIF sample (exiftool-style text). Reads $(SAMPLE_HEIC);
## override it on the command line to point at your own file.
dump-heic: build
	$(RELEASE_BIN) --dump "$(SAMPLE_HEIC)"

## Dump a MOV/MP4 sample. Reads $(SAMPLE_MOV); override as needed.
dump-mov: build
	$(RELEASE_BIN) --dump "$(SAMPLE_MOV)"

# ---- Testing ----------------------------------------------------------------

## Run the XCTest suite.
test:
	swift test

# ---- Packaging --------------------------------------------------------------

## Create dist/ExifChecker.app around the release binary. The bundle carries
## a minimal Info.plist; no asset catalog is required because the UI uses SF
## Symbols exclusively. The bundle is ad-hoc codesigned, which is sufficient
## for running on the local machine; distribution to other Macs would need a
## Developer ID signature plus notarization.
bundle: build
	@echo "Packaging $(APP_BUNDLE)"
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@cp "$(RELEASE_BIN)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/Info.plist"
	@codesign --force --deep --sign - "$(APP_BUNDLE)"
	@codesign --verify --deep --strict "$(APP_BUNDLE)"
	@echo "Done. Open with: open \"$(APP_BUNDLE)\""

## Install the bundled app into /Applications.
install: bundle
	cp -R "$(APP_BUNDLE)" /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app"

# ---- Housekeeping -----------------------------------------------------------

## Remove all build artifacts (.build and dist).
clean:
	rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"
