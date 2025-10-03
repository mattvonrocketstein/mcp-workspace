#!/usr/bin/env -S make -f
# Container entrypoint script 
.SHELL := bash
MAKEFLAGS += --warn-undefined-variables
.DEFAULT_GOAL := help
THIS_MAKEFILE := $(abspath $(firstword $(MAKEFILE_LIST)))
SRC_ROOT := $(shell dirname ${THIS_MAKEFILE})

export CMK_LOG_IMPORTS?=0
export MCPJUNGLE_PORT?=80
export MCP_ROOT?=/opt/mcp

include compose.mk
include automation.mk

component.run=python3 ${MCP_ROOT}/components/


#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
servers_dir=${MCP_ROOT}/servers
prompt_dir=${MCP_ROOT}/prompts
resource_dir=${MCP_ROOT}/resources

prompt_server.run=${component.run}/prompt_server.py ${prompt_dir}
resource_server.run=${component.run}/resource_server.py ${resource_dir}
combined_server.run=${component.run}/combined_server.py

__main__: self.workspace.stat

self.workspace.stat:; tree ${MCP_ROOT}; echo
self.workspace.stat/%:; tree ${MCP_ROOT}/${*}; echo

prompt_server: self.workspace.stat/prompts
	cmd="${prompt_server.run}" ${make} io.inotify/${prompt_dir}

resource_server: self.workspace.stat/resources
	cmd="${resource_server.run}" ${make} io.inotify/${resource_dir}

tool_server: self.workspace.stat/servers
	path=${servers_dir} ${make} flux.watchdog/self.tools.serve

self.tools.serve: io.print.banner/mcpjungle
	@# Starts the server, backgrounds it, 
	@# provisions services, then foregrounds daemon
	$(call log.target, starting mcpjungle on ${MCPJUNGLE_PORT})
	mcpjungle start --port ${MCPJUNGLE_PORT} & SERVER_PID=$$! \
	&& ${make} mcp.init ; wait $$SERVER_PID

combined_server: self.workspace.stat
	cmd="${combined_server.run}" ${make} io.inotify/${MCP_ROOT}/components

# Shims.
# Typically `automation.mk` uses containerized tools, 
# but this script runs in the container!
#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

mcp_workspace.shell.pipe:; bash /dev/stdin
workspace.workspace:; printf "$${entrypoint} $${cmd}" | bash -x /dev/stdin
workspace.workspace.shell.pipe:; bash /dev/stdin
workspace.ps:; echo ''

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
	rm -f /tmp/.X99-lock
	Xvfb :99 -screen 0 1920x1080x16 &
	sleep 2
	/opt/lmstudio/lm-studio --no-sandbox --headless &
	# "--run-as-service", "--headless", "--port", "1234"
	sleep 30
	~/.cache/lm-studio/bin/lms server start --cors &
	sleep 5
	~/.cache/lm-studio/bin/lms server status --json --quiet
	#~/.cache/lm-studio/bin/lms load --gpu max --context-length ${CONTEXT_LENGTH:-4096} ${MODEL_PATH}
	# sleep 60
	sleep 5
	#cp -f /http-server-config.json /root/.cache/lm-studio/.internal/http-server-config.json
	mkdir -p /root/.cache/lm-studio/.internal
	echo '{"port":1234,"cors":true,"logSensitiveData":true,"verbose":false,"logLinesLimit":500,"networkInterface":"0.0.0.0"}' > /root/.cache/lm-studio/.internal/http-server-config.json
	~/.cache/lm-studio/bin/lms server status --json --quiet
	sleep inf

#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
flux.watchdog/%:
	@# Runs the given target once, and again in a loop whenever the given path changes
	@#
	@# USAGE: path='..' make flux.watchdog/<target>
	@#
	cmd="${make} ${*}" ${make} io.inotify/$${path}
	
io.inotify: mk.require.tool/inotifywait
	@# Runs given command once, and again in a loop whenever the given path changes
	@#
	@# USAGE: path='..' cmd='..' make io.inotify
	@#
	$(call log.target, ${dim}path=${no_ansi}$${path}) \
	&& export events="$${events:-modify,create,delete}" \
	&& $(call log.target, ${dim}events=${no_ansi}$${events}) \
	&& $(call log.target, ${cyan_flow_right} ${dim} $${cmd}) \
	&& set -x ; $${cmd} & pid=$$! \
	&& while inotifywait -r -e $${events} $${path}; \
		do kill -KILL $${pid}; $${cmd} & done

io.inotify/%:; path="${*}" ${make} io.inotify
	@# Like `io.inotify`, but accepts path as argument 
	@#
	@# USAGE: cmd='..' ${make} io.inotify/<path>
	
