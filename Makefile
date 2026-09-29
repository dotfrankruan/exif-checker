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
#   .build/release/ExifChecker --dump <file>
#   make dump-heic                      Dump the bundled Desktop test image
#   make dump-mov                       Dump the bundled Desktop test video
# ============================================================================

APP_NAME    := ExifChecker
BUILD_DIR   := .build
DIST_DIR    := dist
APP_BUNDLE  := $(DIST_DIR)/$(APP_NAME).app
RELEASE_BIN := $(BUILD_DIR)/release/$(APP_NAME)
DEBUG_BIN   := $(BUILD_DIR)/debug/$(APP_NAME)

# Test fixtures referenced by the user request.
HEIC_SAMPLE := $(HOME)/Desktop/sample.heic
MOV_SAMPLE  := $(HOME)/Desktop/sample.mov

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

## Dump the Desktop HEIC sample (exiftool-style text).
dump-heic: build
	$(RELEASE_BIN) --dump "$(HEIC_SAMPLE)"

## Dump the Desktop MOV sample (exiftool-style text).
dump-mov: build
	$(RELEASE_BIN) --dump "$(MOV_SAMPLE)"

# ---- Testing ----------------------------------------------------------------

## Run the XCTest suite.
test:
	swift test

# ---- Packaging --------------------------------------------------------------

## Create dist/ExifChecker.app around the release binary. The bundle carries
## a minimal Info.plist; no asset catalog is required because the UI uses SF
## Symbols exclusively. The binary is ad-hoc codesigned so Gatekeeper and
## LaunchServices treat it as a normal local app.
bundle: build
	@echo "Packaging $(APP_BUNDLE)"
	@rm -rf "$(APP_BUNDLE)"
	@mkdir -p "$(APP_BUNDLE)/Contents/MacOS"
	@cp "$(RELEASE_BIN)" "$(APP_BUNDLE)/Contents/MacOS/$(APP_NAME)"
	@cp "Resources/Info.plist" "$(APP_BUNDLE)/Contents/Info.plist"
	@codesign --force --deep --sign - "$(APP_BUNDLE)" 2>/dev/null || true
	@echo "Done. Open with: open \"$(APP_BUNDLE)\""

## Install the bundled app into /Applications.
install: bundle
	cp -R "$(APP_BUNDLE)" /Applications/
	@echo "Installed to /Applications/$(APP_NAME).app"

# ---- Housekeeping -----------------------------------------------------------

## Remove all build artifacts (.build and dist).
clean:
	rm -rf "$(BUILD_DIR)" "$(DIST_DIR)"
