SHELL := /bin/sh

NODE22_PREFIX := $(shell command -v brew >/dev/null 2>&1 && brew --prefix node@22 2>/dev/null)
ifneq ($(strip $(NODE22_PREFIX)),)
export PATH := $(NODE22_PREFIX)/bin:$(PATH)
endif

MODEL_NAME := sherpa-onnx-streaming-paraformer-bilingual-zh-en
MODEL_DIR := models/$(MODEL_NAME)
MODEL_BASE_URL := https://huggingface.co/csukuangfj/$(MODEL_NAME)/resolve/main
MODEL_FILES := encoder.int8.onnx decoder.int8.onnx tokens.txt
MODEL_PATHS := $(addprefix $(MODEL_DIR)/,$(MODEL_FILES))

.PHONY: run setup check-node clean-model ios-build ios-test ios-ui-smoke ios-secret-scan ios-ci

run: setup
	@echo "Starting expression-trainer..."
	@npm start

setup: check-node node_modules $(MODEL_PATHS)

check-node:
	@node -e "const major=Number(process.versions.node.split('.')[0]); if (major < 18) { console.error('Node.js 18+ is required'); process.exit(1); } console.log('Using Node.js ' + process.versions.node)"

node_modules: package.json package-lock.json
	@echo "Installing Node.js dependencies..."
	@npm ci

$(MODEL_DIR):
	@mkdir -p "$@"

$(MODEL_DIR)/%: | $(MODEL_DIR)
	@echo "Downloading $*..."
	@curl --fail --location --retry 3 --retry-delay 2 --progress-bar \
		"$(MODEL_BASE_URL)/$*" --output "$@.part"
	@mv "$@.part" "$@"

clean-model:
	@rm -f $(MODEL_PATHS)

IOS_PROJECT := clients/ios/exp-trainer/exp-trainer.xcodeproj
IOS_SCHEME := exp-trainer
IOS_DESTINATION ?= platform=iOS Simulator,name=iPhone 17 Pro
IOS_DERIVED_DATA ?= /tmp/expression-trainer-ios-derived-data

ios-build:
	xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" \
		-destination 'generic/platform=iOS Simulator' \
		-derivedDataPath "$(IOS_DERIVED_DATA)" CODE_SIGNING_ALLOWED=NO build

ios-test:
	xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" \
		-destination '$(IOS_DESTINATION)' \
		-derivedDataPath "$(IOS_DERIVED_DATA)" CODE_SIGNING_ALLOWED=NO \
		-only-testing:exp-trainerTests test

ios-ui-smoke:
	xcodebuild -project "$(IOS_PROJECT)" -scheme "$(IOS_SCHEME)" \
		-destination '$(IOS_DESTINATION)' \
		-derivedDataPath "$(IOS_DERIVED_DATA)" CODE_SIGNING_ALLOWED=NO \
		-only-testing:exp-trainerUITests/exp_trainerUITests/testAllTwentyOneDesignStatesLaunch test

ios-secret-scan:
	bash clients/ios/exp-trainer/Scripts/check-secrets.sh

ios-ci: ios-secret-scan ios-build ios-test
