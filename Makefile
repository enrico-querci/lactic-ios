# Lactic iOS — common tasks.
#
# Build settings live in Configs/*.xcconfig and the project structure lives in
# project.yml. Lactic.xcodeproj is generated and git-ignored, so run
# `make project` after pulling or editing project.yml.

SIMULATOR ?= iPhone 17 Pro
IOS       ?= 26.5
PROJECT   := Lactic.xcodeproj
PACKAGES  := LacticCore LacticKit LacticUI

# Overridable wholesale, because a machine that lacks this exact runtime — a CI
# runner, or a laptop a version behind — should not need the Makefile edited.
# CI passes a UDID it discovered from `simctl list devices available`.
DESTINATION ?= platform=iOS Simulator,name=$(SIMULATOR),OS=$(IOS)

.DEFAULT_GOAL := help
.PHONY: help project build test test-packages lint format clean

help: ## Show this help
	@grep -E '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

project: ## Regenerate Lactic.xcodeproj from project.yml
	xcodegen generate

build: project ## Build both app schemes for the simulator
	@for scheme in Lactic LacticStudio; do \
		echo "--- building $$scheme ---"; \
		xcodebuild build -project $(PROJECT) -scheme $$scheme -destination "$(DESTINATION)" -quiet || exit 1; \
	done

test-packages: ## Run the Swift Package tests on the host (fast, no simulator)
	@for package in $(PACKAGES); do \
		echo "--- testing $$package ---"; \
		(cd Packages/$$package && swift test) || exit 1; \
	done

test: project test-packages ## Run package tests and both app test schemes
	@for scheme in Lactic LacticStudio; do \
		echo "--- testing $$scheme ---"; \
		xcodebuild test -project $(PROJECT) -scheme $$scheme -destination "$(DESTINATION)" -quiet || exit 1; \
	done

lint: ## Check formatting and lint rules without changing anything
	swiftformat --lint .
	swiftlint lint --quiet

format: ## Apply formatting
	swiftformat .
	swiftlint --fix --quiet

clean: ## Remove generated project and build artefacts
	rm -rf $(PROJECT) DerivedData
	@for package in $(PACKAGES); do rm -rf Packages/$$package/.build; done
