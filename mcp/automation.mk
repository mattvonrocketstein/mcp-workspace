# Automation for working with (containerized) mcpjungle
#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

mcpjungle.img_tag=latest-stdio
mcp.server=http://combined_server/mcp
mcp.inspector.base=@modelcontextprotocol/inspector \
		--cli $${MCP_SERVER:-${mcp.server}} --transport http 


export LLM_MODEL?=qwen3:latest
export OLLAMA_URL?=http://ollama:11434
export MCP_URL?=http://combined_server/mcp

export MCPJUNGLE_IMAGE_TAG?=${mcpjungle.img_tag}
export MCP_TOOL_PORT?=80
define _mcp.inspector
	$(call log.maybe,${@} ${sep} ..) && quiet=1 \
	entrypoint=npx \
	cmd="${mcp.inspector.base} --method ${1}/list" \
		${make} workspace.workspace 2>/dev/null
endef
define _mcp.create.any
	ls $(strip ${3}) >/dev/null \
	&& name="`cat $(strip ${3}) | ${jq} -r .name`" \
	&& $(call log.target.part1, ${dim_ital}$${name}) \
	&& quiet=1 ${make} mcp.list.$(strip ${1}) | grep -w $${name} >/dev/null \
	; case $$?  in \
		0) $(call log.target.part2, ${dim_green}${GLYPH_CHECK} found);; \
		*) $(call log.target.part2, ${yellow} not installed yet) \
			&& ( \
				quiet=1 entrypoint=mcpjungle \
				cmd="$(strip ${2}) -c $(strip ${3})" \
				${make} workspace.workspace 2>&1 | ${stream.glow} );; \
	esac
endef
#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░
workspace.build.serve/%:; ${make} workspace.${*}.build workspace.${*}.restart
workspace.rsrc.%:; ${make} workspace.resources.${*}
	@# Shortcut for workspace.resources

workspace.list.containers: 
	${make} workspace.ps | ${jq} '{containers:.}'
workspace.stat:; 
	@# Returns JSON for all groups/servers/tools registered with mcpjungle
	${make} \
		workspace.list.containers \
		mcp.list.servers mcp.list.groups mcp.list.tools \
		mcp.list.prompts mcp.list.resources  \
	| ${jq} -s 'add'

workspace.serve: workspace.serve/mcp 
workspace.serve.fg: workspace.serve.fg/mcp
workspace.shell: workspace.workspace.shell 
	@# Debugging shell for the main container
workspace.serve/%:; ${make} compose.with_profile/${*}/workspace.down,workspace.up.detach
workspace.serve.fg/%:; ${make} compose.with_profile/${*}/workspace.down,workspace.up


#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

lmstudio.serve: workspace.lmstudio.build workspace.lmstudio.up.detach flux.timeout/15/workspace.lmstudio.logs lmstudio.init
#COMPOSE_PROFILES=lmstudio ${make} workspace.restart
lmstudio.init: lms.get/paraphrase-MiniLM-L6-v2-GGUF lms.load/paraphrase-MiniLM-L6-v2-GGUF lms.status
# workspace.lmstudio.exec/.lmstudio.init
# .lmstudio.init: 
# 	lms load -y paraphrase-MiniLM-L6-v2-GGUF --identifier paraphrase

# ${make} lmstudio.load/
#lmstudio.load/text-embedding-paraphrase-minilm-l6-v2
lmstudio.load/%:; cmd="load ${*} -y" ${make} lmstudio.cli
#    lms load text-embedding-paraphrase-minilm-l6-v2
lmstudio.cli:; cmd="/opt/lmstudio/resources/app/.webpack/lms $${cmd:---help}" ${make} workspace.lmstudio.exec
lms.get/%:; cmd="get ${*} -y" ${make} lmstudio.cli
lms.load/%:; cmd="load -y ${*}" ${make} lmstudio.cli
# lms.ls:; cmd="ls" ${make} lmstudio.cli
lms.status:; cmd="server status --json" ${make} lmstudio.cli 2>/dev/null | ${jq} . 
lmstudio.stat: workspace.lmstudio.ps lmstudio.lms.status
# lmstudio.%:; set -x && ${make} workspace.lmstudio.${*} || true

#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

ollama.serve.fg: compose.with_profile/ollama/mcp.restart
ollama.serve:; COMPOSE_PROFILES=ollama ${make} mcp.stop mcp.up.detach
ollama.create/%:
	ls ${*} >/dev/null
	cmd="ollama create --file /workspace/${*} `basename -s.Modelfile ${*}`" ${make} workspace.ollama.exec

mcp.ollmcp:
	COMPOSE_PROFILES=ollama,tools \
	entrypoint=ollmcp \
	cmd="--model $${LLM_MODEL} --host $${OLLAMA_URL} --mcp-server-url $${MCP_URL}" \
	${make} workspace.ollmcp

# Lifecycle stuff
#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

mcp.init: io.print.banner/mcp.init mcp.load.servers mcp.load.groups workspace.stat
	@# Start, provision, and inspect the the MCP server(s).

mcp.assert_tool_ready/%:
	@# FIXME: abstract to automation.mk
	$(call log.target.part1, ${*})
	quiet=1 ${make} mcp.list.tools | grep ${*}__ > /dev/null \
	|| ( $(call log.target.part2, failed); exit 39) 
	$(call log.target.part2, ok)

# List Assets on the workspace's combined_server
#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

mcp.list: mcp.list.servers mcp.list.groups mcp.list.tools
	@# Like `workspace.stat`, but more detail, and not JSON 
mcp.list.prompts:; $(call _mcp.inspector, prompts) | ${jq} .prompts[].name | ${jq} -s '{prompts: .}'
mcp.list.tools:; $(call _mcp.inspector, tools) | ${jq} .tools[].name | ${jq} -s '{tools: .}'
mcp.list.resources:; $(call _mcp.inspector, resources)| ${jq} .resources[].name | ${jq} -s '{resources: .}'
mcp.list.groups: .mcpjungle.list.groups
mcp.list.servers: .mcpjungle.list.servers	

.mcpjungle.list.%:
	@# Ask mcpjungle to run "list" for the given kind.  
	@# Expects one of { group | server }.  
	@# Returns clean, newline-separated output for available resource names, no description included.
	echo '\
			mcpjungle list ${*} 2>&1  \
			| grep -E '^[0-9]+[.]' \
			| cut -d " " -f2' \
		| quiet=1 ${make} workspace.workspace.shell.pipe | ${jq} -Rs 'split("\n") | map(select(length > 0))' | ${jq} -s '{${*}: .[]}'

# Other MCP Asset CRUD
#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

mcp.load.groups:
	@# Load all defined tool-groups from config file(s)
	ls ${MCP_ROOT}/groups/*json | ${flux.each}/mcp.create.group

mcp.load.servers:
	@# Load all defined servers from config file(s)
	ls ${MCP_ROOT}/tools/*json | ${flux.each}/mcp.create.server
mcp.create.group/%:
	@# Creates an MCP tool-group from the given JSON config file
	$(call _mcp.create.any, groups, create group, ${*}) 
	
mcp.create.server/%: 
	@# Creates 1 MCP server from the given JSON config file
	$(call _mcp.create.any, servers, register, ${*}) || $(call log.target, ${red}error creating ${*})

mcp.shell: workspace.workspace.shell
	@# Debugging shell in the workspace container

mcp.tools.assert_running:
	@# FIXME: abstract to compose.mk
	$(call log.target.part1, asserting container is running)
	${make} workspace.tools.ps | ${jq} .State | grep -i running > /dev/null \
	|| ( $(call log.target.part2, failed); exit 39) 
	$(call log.target.part2, ok)


stream.escape.json=sed 's/"/\\"/g'
mcp.invoke=${make} mcp.invoke
mcp.invoke/%:
	@# Accepts JSON input on stdin, and streams it as input to the named tool
	$(call log.target, streaming data to tool ${bold}${*})
	${stream.stdin} | ${stream.peek} | mcpjungle invoke ${*} --input "`${stream.stdin} | ${stream.escape.json}`" 2>&1 


#░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░

mcp.help: mk.namespace.filter/mcp.
	@# List help for the `mcp` namespace

mcp.help.all: help.local.all
	@# Help for this namespace
	
