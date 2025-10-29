#!/usr/bin/env -S make -f
# Container entrypoint script 
.SHELL := bash
MAKEFLAGS += --warn-undefined-variables
.DEFAULT_GOAL := help
THIS_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))
SRC_ROOT := $(shell dirname ${THIS_MAKEFILE})

export CMK_LOG_IMPORTS?=0
export MCP_TOOL_PORT?=80
export MCP_ROOT?=/opt/mcp

include compose.mk
include automation.mk

component.run=python3 ${MCP_ROOT}/components


servers_dir=${MCP_ROOT}/tools
prompt_dir=${MCP_ROOT}/prompts
resource_dir=${MCP_ROOT}/resources

prompt_server.run=${component.run}/prompt_server.py ${prompt_dir}
resource_server.run=${component.run}/resource_server.py ${resource_dir}
combined_server.run=${component.run}/combined_server.py

#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

__main__: workspace.describe.folder

workspace.describe.folder:; tree ${MCP_ROOT}; echo
workspace.describe.folder/%:; tree ${MCP_ROOT}/${*}; echo

prompt_server: workspace.describe.folder/prompts
	cmd="${prompt_server.run}" ${make} io.inotify/${prompt_dir}

resource_server: workspace.describe.folder/resources
	cmd="${resource_server.run}" ${make} io.inotify/${resource_dir}
	# ${resource_server.run}

tool_server: workspace.describe.folder/tools
	path=${servers_dir} ${make} flux.watchdog/self.tools.serve

self.tools.serve: io.print.banner/mcpjungle
	@# Starts the server, backgrounds it, 
	@# provisions services, then foregrounds daemon
	$(call log.target, starting mcpjungle on ${MCP_TOOL_PORT})
	mcpjungle start --port ${MCP_TOOL_PORT} & SERVER_PID=$$! \
	&& ${make} mcp.init ; wait $$SERVER_PID

combined_server: workspace.describe.folder
	cmd="${combined_server.run}" ${make} io.inotify/${MCP_ROOT}/components

omnibus:
	$(call log.target, starting all servers)
	set -x \
	&& rm -f /opt/mcp/tools/markitdown.json \
	&& echo 'registry_url: http://localhost:8083' > ~/.mcpjungle.conf \
	&& MCP_PROMPT_PORT=8081 ${make} prompt_server & \
	MCP_RESOURCE_PORT=8082 ${make} resource_server & \
	MCP_TOOL_PORT=8083 ${make} tool_server & \
	export MCP_SUBSERVERS=localhost:8081,localhost:8082,localhost:8083 \
	&& MCP_SERVER=localhost \
	&& ${make} combined_server

#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

engine.ollama: io.print.banner/ollama io.env/OLLAMA,LLM
	$(call log.target,starting..) && set -x && ollama serve

engine.local_ai: io.print.banner/local-ai io.env/OLLAMA,LLM
	$(call log.target,starting..) \
	&& $(call log.target.part1, checking version..) \
	&& tmp="`local-ai --version`" \
	&& $(call log.target.part2, $${tmp}) \
	&& set -x && cd / \
	&& local-ai run --address=":$${LLM_PORT:-}" 

engine.lmstudio: io.print.banner/lmstudio io.env/OLLAMA,LLM,MODEL
	$(call log.target,)
	mkdir -p /root/.cache/lm-studio/.internal
	echo '{"port":1234,"cors":true,"logSensitiveData":true,"verbose":false,"logLinesLimit":500,"networkInterface":"0.0.0.0"}' \
		> /root/.cache/lm-studio/.internal/http-server-config.json
	xpra start :10 --bind-tcp=0.0.0.0:6274 --mdns=no --printing=no --speaker=no --sharing=yes --audio=no --pulseaudio=no --webcam=no --microphone=off --html=on --daemon=no --window-close=disconnect --file-transfer=no --tray=no --system-tray=no --exit-with-children --start-child '/opt/lmstudio/lm-studio --no-sandbox'
	# rm -f /tmp/.X99-lock
	# Xvfb :99 -screen 0 1920x1080x16 &
	# sleep 2
	# /opt/lmstudio/lm-studio --no-sandbox --headless &
	# # "--run-as-service", "--headless", "--port", "1234"
	# sleep 30
	# ~/.cache/lm-studio/bin/lms server start --cors &
	# sleep 5
	# ~/.cache/lm-studio/bin/lms server status --json --quiet
	# #~/.cache/lm-studio/bin/lms load --gpu max --context-length ${CONTEXT_LENGTH:-4096} ${MODEL_PATH}
	# # sleep 60
	# sleep 5
	# #cp -f /http-server-config.json /root/.cache/lm-studio/.internal/http-server-config.json
	# ~/.cache/lm-studio/bin/lms server status --json --quiet
	# sleep inf

# Shims.
# Typically `automation.mk` uses containerized tools, 
# but this script runs in the container!
#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

mcp_workspace.shell.pipe:; bash /dev/stdin
workspace.workspace:; printf "$${entrypoint} $${cmd}" | bash -x /dev/stdin
workspace.workspace.shell.pipe:; bash /dev/stdin
workspace.ps:; echo ''

