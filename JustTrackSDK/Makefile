BLUE_COLOR=\033[0;34m
DEFAULT_COLOR=\033[0m 

define print_message
	@echo "${BLUE_COLOR}\n🔨 ~~~ $1 ~~~${DEFAULT_COLOR}\n"
endef

all: run_scripts generate_project

run_scripts:
	$(call print_message,Running scripts)
	./scripts/generate.js
	./scripts/updateTestAppVersion.sh
	./scripts/generateCredentials.sh

generate_project:
	$(call print_message,Generating project)
	xcodegen generate
	./scripts/fix_test_scheme.sh

format:
	$(call print_message,Formatting Swift code)
	./scripts/swiftformat.sh format

lint:
	$(call print_message,Linting Swift code)
	./scripts/swiftformat.sh lint

.PHONY: all run_scripts generate_project format lint