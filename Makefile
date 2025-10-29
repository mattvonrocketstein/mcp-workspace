# Project Automation
#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

.SHELL := bash
# .SHELLFLAGS := -euo pipefail -c
MAKEFLAGS += --warn-undefined-variables
.DEFAULT_GOAL := help

THIS_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))
SRC_ROOT := $(shell dirname ${THIS_MAKEFILE})
docs.root=docs/
# export CMK_LOG_IMPORTS?=1
export COMPOSE_PROFILES?=all
export MKDOCS_LISTEN_PORT=8003
export MCP_WORKSPACE_TAG?=mcp_workspace:local

include .cmk/compose.mk
include mcp/automation.mk
export MCP_ROOT=./mcp/
$(call compose.import.as, namespace=workspace file=containers/__main__.yml)

py.src_root:=mcp/
$(call mk.import.plugins, py.mk actions.mk docs.mk json.mk)

.PHONY: build docs docs/includes

__main__: help.local

panic: docker.stop.all

clean: flux.stage/clean 
	@# Project Clean 
	rm -f .tmp.*

init: flux.stage/init mk.stat docker.stat
	@# Project init. 
	set -x && pip3 install --break-system-packages -r mcp/requirements.dev.txt 

build: flux.stage/build flux.timer/.build
	@# Project build. 
.build:	workspace.base.build workspace.build

serve: workspace.serve
serve.fg: workspace.serve.fg

test: flux.stage/test flux.timer/flux.and/smoke-test,test-integrations

# Integration Tests
#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

test-integrations itest: mcp.tools.assert_running
	@# Test the container built by the compose-file
	$(call log.test_case, checking status for resources..)
	${make} workspace.stat test.tools

test.tools: test.tool.filesystem test.tool.tasks test.tool.markitdown
test.tool.filesystem: mcp.assert_tool_ready/filesystem
test.tool.tasks: mcp.assert_tool_ready/tasks workspace.workspace.dispatch/.test.task_tool
test.tool.markitdown: mcp.assert_tool_ready/markitdown workspace.workspace.dispatch/.test.markitdown
.test.markitdown:
	$(call log.target, exercising markdown server)
	${jb} uri=https://microsoft.github.io/prompt-engineering/ \
		| ${mcp.invoke}/markitdown__convert_to_markdown | head -5 | ${stream.as.log}
.test.task_tool:
	$(call log.target, exercising task-management server)
	${jb} workspace=. source_path=tasks.md | ${mcp.invoke}/tasks__tasks_setup | ${stream.as.log}
	${jb} status=todo 'texts:[,]=plan foo' | ${mcp.invoke}/tasks__tasks_add | ${stream.as.log}
	${jb} status=todo 'texts:[,]=implement bar' | ${mcp.invoke}/tasks__tasks_add | ${stream.as.log}
	echo '{}' | ${mcp.invoke}/tasks__tasks_summary | ${stream.as.log}

# Smoke Tests
#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

$(call docker.import, namespace=docker.workspace img=mcp.local:workspace)
smoke-test: docker.workspace.dispatch/.smoke-test
.smoke-test:
	pushd /opt/mcp \
	&& make workspace.stat


# Import tox environments.
# After tox describes/manages a virtualenv, it calls this Makefile 
# from that virtualenv, passing control back to `self.*` targets in this section
#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
# $(call tox.import, ruff type-check docs-build venv normalize itest stest utest)
$(call tox.import, normalize static-analysis)
validate.json: json.validate/mcp
validate.compose:; ls containers/*.yml | ${flux.each}/compose.validate
validate lint: validate.compose validate.json validate.makefiles static-analysis
validate.makefiles: mk.validate/mcp/automation.mk 
self.static-analysis: py.static-analysis