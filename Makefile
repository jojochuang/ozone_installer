# Makefile for Ozone Installer precommit checks
# This provides convenient commands for running precommit checks locally

.PHONY: help lint shellcheck format syntax test-all test-commands test-functions test-precommit clean

help: ## Show this help message
	@echo "Ozone Installer - Precommit Checks"
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

lint: shellcheck ## Run all linting checks

shellcheck: ## Run shellcheck on all shell scripts
	@echo "Running shellcheck on shell scripts..."
	@find . -name "*.sh" -type f | while read -r script; do \
		echo "Checking $$script"; \
		shellcheck "$$script"; \
	done

shellcheck-errors-only: ## Run shellcheck but only fail on errors
	@echo "Running shellcheck (errors only) on shell scripts..."
	@find . -name "*.sh" -type f | while read -r script; do \
		echo "Checking $$script"; \
		shellcheck -S error "$$script"; \
	done

format: ## Check shell script formatting with shfmt
	@if command -v shfmt >/dev/null 2>&1; then \
		echo "Checking shell script formatting..."; \
		find . -name "*.sh" -type f | while read -r script; do \
			echo "Checking format of $$script"; \
			shfmt -d "$$script" || echo "Consider running: shfmt -w $$script"; \
		done; \
	else \
		echo "shfmt not found. Install with:"; \
		echo "  curl -L https://github.com/mvdan/sh/releases/download/v3.7.0/shfmt_v3.7.0_linux_amd64 -o shfmt"; \
		echo "  chmod +x shfmt && sudo mv shfmt /usr/local/bin/"; \
	fi

format-fix: ## Fix shell script formatting with shfmt
	@if command -v shfmt >/dev/null 2>&1; then \
		echo "Fixing shell script formatting..."; \
		find . -name "*.sh" -type f -exec shfmt -w {} \;; \
		echo "Formatting fixed"; \
	else \
		echo "shfmt not found. Install first with 'make format'"; \
	fi

syntax: ## Check shell script syntax
	@echo "Checking shell script syntax..."
	@find . -name "*.sh" -type f | while read -r script; do \
		echo "Checking syntax of $$script"; \
		bash -n "$$script"; \
	done

permissions: ## Check executable permissions on shell scripts
	@echo "Checking executable permissions on shell scripts..."
	@find . -name "*.sh" -type f | while read -r script; do \
		if [ ! -x "$$script" ]; then \
			echo "❌ $$script is not executable"; \
			echo "Fix with: chmod +x $$script"; \
		else \
			echo "✅ $$script has correct executable permissions"; \
		fi; \
	done

markdown: ## Check markdown files (if markdownlint is available)
	@if command -v markdownlint >/dev/null 2>&1; then \
		echo "Running markdownlint on markdown files..."; \
		find . -name "*.md" -type f -exec markdownlint {} \;; \
	else \
		echo "markdownlint not found. Install with: npm install -g markdownlint-cli"; \
	fi

test-all: shellcheck-errors-only syntax permissions ## Run all essential precommit checks
	@echo "✅ All essential precommit checks passed!"

test-commands: ## Test shell script command options (as per README)
	@echo "Testing shell script command options..."
	@./tests/test_setup_rocky9_ssh.sh >/dev/null && echo "✅ Command option tests passed!" || (echo "❌ Command option tests failed!" && exit 1)

test-functions: ## Test shell script functions (basic unit tests)
	@echo "Testing shell script functions..."
	@./tests/test_script_functions.sh >/dev/null && echo "✅ Function tests passed!" || (echo "❌ Function tests failed!" && exit 1)

test-precommit: ## Run all precommit tests (command options + unit tests)
	@echo "Running comprehensive precommit tests..."
	@./tests/run_all_tests.sh && echo "✅ All precommit tests passed!" || (echo "❌ Precommit tests failed!" && exit 1)

clean: ## Clean up temporary files
	@echo "Cleaning up temporary files..."
	@find . -name "*.tmp" -type f -delete
	@find . -name "*.log" -type f -delete
	@echo "Cleanup completed"

install-tools: ## Install precommit tools (requires sudo)
	@echo "Installing precommit tools..."
	@sudo apt-get update
	@sudo apt-get install -y shellcheck
	@curl -L "https://github.com/mvdan/sh/releases/download/v3.7.0/shfmt_v3.7.0_linux_amd64" -o shfmt
	@chmod +x shfmt
	@sudo mv shfmt /usr/local/bin/
	@if command -v npm >/dev/null 2>&1; then \
		npm install -g markdownlint-cli; \
	else \
		echo "npm not found, skipping markdownlint installation"; \
	fi
	@echo "Tools installation completed"