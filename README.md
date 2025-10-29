## About

This is a rough-and-ready template repository for building and bundling MCP stacks.  The emphasis is on containers, and folder-based, in-repo configuration, with a focus on local-first workflows.  You can use it to work with groups of related MCP servers using [mcpjungle](https://github.com/mcpjungle/MCPJungle) and [fastmcp](https://gofastmcp.com/).  Besides stacking together MCP servers, it can help with plug-and-play for related assets like *tool-groups*, *prompt templates*, and *resources*.

Making MCP experimentation and bundling easy is the primary goal, but there's also some boilerplate and support automation for containerized inference engines, including `ollama`, `lmstudio`, and `local-ai`.

**Why?** There's lots of frameworks for agentic workflows, but **reproducible and portable manifests for AI-stack configurations**, i.e. "workspaces", is something that is conspicuously missing.  Read on in the [Motivation & Context](#motivation-context) section if you want a long-format answer, or jump to [Usage section](#general-usage) to dive in.  Jump to the [Related Work](#related-work) section for alternatives and inspiration.

----------------------------------

## General Usage

There are two main ways to use this project:

**Use the published [docker image](#docker-image) directly or extend it.**  By default, the MCP registry includes tool-servers for things like filesystem / shell / git access, but you can wipe those out and add others instead.  This approach is good if you're looking to bundle/ship a related group of services, but don't want separate images for each, and don't want to push the configuration/installation work onto users.

**Fork this repository and work in-place,** structuring your own experiments around the [project layout](#project-layout) and leveraging the existing [project automation](#project-automation).  This approach is more useful if you need an AI stack with multiple components, but you also don't really expect to ship that stack anywhere. (Is your stack "project local", and tightly coupled to the code/data that it lives near?)  Besides development *with* help from MCP servers, this approach is also useful for active development *on* related MCP servers.

If you decide to experiment or work in-place there are no dependencies except for `make` and `docker`.  Clone recursively to pick up all the automation though, because some of it is in submodules.

```bash
$ git clone --recursive git@github.com:mattvonrocketstein/mcp-workspace.git
```

----------------------------------

## How it Works

### Core MCP Servers
<a name='core-mcp-servers'></a>
<a name='core-mcp'></a>

This project defines a `prompts` server, a `tools` server, and a `resources` server which are exposed as a single `combined_server`.  By default, each server runs in a container, each is launched from [main workspace image](#workspace-image).  Each internal server expects folder-based configuration, and is wrapped with a supervisor that restarts automatically if filesystem config changes.  

* **`tools` server** *(internal)*: Starts `mcpjungle`, loading assets from [mcp/tools/](mcp/tools) and [mcp/groups/](mcp/groups).

* **`prompts` server** *(internal)*: Starts a `fastmcp` server, automatically loading both markdown-files or prompts-in-python from [mcp/prompts/](mcp/prompts). *( [code](mcp/components/prompt_server.py) )*

* **`resources` server** *(internal)*: Starts a `fastmcp` server, loading JSON-schema or fastmcp-style resources in python from [mcp/resources/](mcp/resources). *( [code](mcp/components/resource_server.py) )*

* **`combined_server`** *(optionally exposed to the docker host)*: Using [fastmcp server composition](https://fastmcp.wiki/en/servers/composition#server-composition), `combined_server` binds all of the others together in the same namespace on a single dynamic server.  To avoid the additional complexity of guessing where everything is, aggregation is naive: *No prefixes are used for namespacing subserver assets*, so beware name collisions! *( [code](mcp/components/combined_server.py) )*

A quick overview of implementation details:

* **`mcpjungle`** works as a tool-registry that's language and framework agnostic, allowing you to directly run (or reference URLs for) other MCP subservers.  Subservers using stdio transport is a good idea to keep things self-contained, and may be launched as usual with npx, uvx, docker, etc.  The upside is JSON config that's familiar, plus it's an aggregator that's indifferent about what kind of servers it can combine.  Typically though mcpjungle subserver config must be *pushed* to the mcpjungle-server from the mpcjungle client, rather than the server loading it at startup.  This project adds flexible bootstrap and auto-reload-on-file-changes automation that can apply/update all the relevant config in the [associated folders](#project-layout).
* **`fastmcp`** is used for prompts and resources because [upstream support for prompt/resource management in mcpjungle](https://github.com/mcpjungle/MCPJungle/issues/73) isn't done yet.  Both the `prompts` and `resources` servers work in a similar way, automatically loading python-backed asset descriptions or "flat" assets from [associated folders](#project-layout).  Server implementations are small and can be found in the [mcp/components](mcp/components) folder.

Other things that are worth nothing:

1. *Technically,* there's no limits on the "kinds" that `fastmcp` can load in [subfolders](#project-layout), e.g. the prompt-server and the resource-server can both describe general MCP resources (including  servers, prompts, etc).  For example, the prompt-server defines a `list_prompts` tool, and the resources-server defines a `list_resources` tool.  Prompts/resources are separated anyway for convenience and customization.  This leaves open the possibility of deploying them separately, or adding new processes for automatically converting other file types to managed MCP resources.
1. *Although slicing assets by tags* is still [under discussion in the MCP spec](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/1300) it's already [supported for fastmcp kinds](https://gofastmcp.com/servers/prompts#param-tags) and supported in general via [mcpjungle groups](https://github.com/mcpjungle/MCPJungle?tab=readme-ov-file#tool-groups).

To bring up all services use `make serve`.  Fine-grained command/control for the individual servers is also available; see [the rest of the automation docs here](#project-automation).

----------------------------------

### Workspace Image
<a name=main-image></a><a name=workspace-container></a>

All servers are instances of the same image, i.e. `mcp-workspace:local` as defined in [containers/mcp.yml](containers/mcp.yml).  *(If you're working with a repo clone, you can build this with `make build`. See [this section](#docker) for more discussion about using the published image instead.)*

Besides access to `fastmcp` and the `mcpjungle` client/server, there are several other conveniences baked in:

* `npx`, `uvx`, and `docker`
* [modelcontextprotocol/inspector](https://github.com/modelcontextprotocol/inspector)
* [mcptool](https://github.com/f/mcptools) (and the golang stack that builds it)
* Any pip dependencies that are mentioned in [containers/requirements.txt](containers/requirements.txt)
* Any npm dependencies that are precached in [containers/mcp.yml](containers/mcp.yml)

----------------------------------

## Project Layout

Configuration for MCP kinds are found in these subfolders:

* [mcp/tools/](mcp/tools/)
* [mcp/groups/](mcp/groups/)
* [mcp/prompts/](mcp/prompts/)
* [mcp/resources/](mcp/resources/)

All folders have individual README's.. see those files for more hints.  To disable any asset, just move it to the "disabled" subfolder in the same directory.

When the [workspace image](#workspace-image) is built, everything in the `mcp/` tree goes to `/opt/mcp`.  Because mcp-workspace is stateless and configured from scratch at every bootstrap, you can override / extend resources like the [default builtin servers](#docker-image) by overriding the volume for `/opt/mcp/tools`.

Containers for `prompts`, `resources`, `tools`, and `combined_server` are all defined in [containers/mcp.yml](containers/mcp.yml).  These extend the same base, but provide different entrypoints.  See [containers/inference.yml](containers/inference.yml) for ollama/lmstudio; see [containers/site.yml](containers/site.yml) for other ancillary containers.

----------------------------------

## What's in the Box?
<a name=default-servers></a>

Whatever you want, since the point is more about the packaging and bundling itself than the specific contents.  But default servers include:

* **filesystem access:** [npm://modelcontextprotocol/server-filesystem](https://www.npmjs.com/package/@modelcontextprotocol/server-filesystem)
* **tasks management:** [github://flesler/mcp-tasks](https://github.com/flesler/mcp-tasks) 
* **shell access:** [pypi://mcp-server-shell](https://pypi.org/project/mcp-server-shell/)
* **markdown convert/extract:** [github://microsoft/markitdown-mcp](https://github.com/microsoft/markitdown/tree/main/packages/markitdown-mcp)

Still evaluating:

* [gh://idosal/git-mcp](https://github.com/idosal/git-mcp)
* [gh://arabold/docs-mcp-server](https://github.com/arabold/docs-mcp-server)
* [gh://modelcontextprotocol/mcp-server-git](https://github.com/modelcontextprotocol/servers/tree/main/src/git), [@pypi](https://pypi.org/project/mcp-server-git/)
* [gh://awwaiid/mcp-server-taskwarrior](https://github.com/awwaiid/mcp-server-taskwarrior) [npm://mcp-server-taskwarrior](https://www.npmjs.com/package/mcp-server-taskwarrior)
* Basic RAG without dependencies??

----------------------------------

## Using the Published Docker Image
<a name=docker-image></a>

Usage via docker-compose will usually be the most convenient and flexible option.  Start with [containers/mcp.yml](containers/mcp.yml) and just change the `FROM` lines to use the ghcr image `ghcr.io/mattvonrocketstein/mcp-workspace:latest`.

Using docker directly with the published image will at least involve adding a volume override, specifying a server entrypoint.  For example if you're just interested in a prompt-server, you can override the folder and make it available from the host on port 8086 like this:

```bash
# Override path to prompts, listening on 8086
$ docker run -it -p 8086:80 -v /path/to/prompts:/opt/mcp/prompts \
  ghcr.io/mattvonrocketstein/mcp-workspace:latest prompt_server
```

Launching containers piecewise *without* docker-compose is tedious since you'll have to manually manage the internal network.  Not really recommended, but you'd need to do something like this:

```bash
# Create the network containers will share
$ docker network create mcp

# Run something similar for each of tools/prompts/resource servers 
$ docker run -it --network mcp \
  --hostname prompts -v /path/to/prompts:/opt/mcp/prompts \
  ghcr.io/mattvonrocketstein/mcp-workspace:latest prompt_server
$ docker run -it --network mcp \
  --hostname resources -v /path/to/resources:/opt/mcp/resources \
  ghcr.io/mattvonrocketstein/mcp-workspace:latest resource_server

# Tools server requires extra volume mounts-- 
#   a workspace so that the filesystem toolserver has host access, 
#   a docker socket, so that mcpjungle can use other dockerized servers 
$ docker run -it --network mcp -v /var/run/docker.sock:/var/run/docker.sock \
  --hostname tools -v /path/to/tools:/opt/mcp/tools -v .:/workspace -w /workspace \
  ghcr.io/mattvonrocketstein/mcp-workspace:latest tool_server

# Launch the combined server on the same network, forwarding a single port to host.
$ docker run -it --network mcp -p 8089:80 \
  ghcr.io/mattvonrocketstein/mcp-workspace:latest combined_server
```

To launch *all* servers in a single container, use the `omnibus` entrypoint:

```bash
$ docker run -it -p 8089:80 -v .:/workspace -w /workspace \
  -v /var/run/docker.sock:/var/run/docker.sock mcp-workspace:local omnibus
```

To extend the published container, start a Dockerfile like this:

```Dockerfile
FROM ghcr.io/mattvonrocketstein/mcp-workspace:latest
# .. Pre-cache other MCP services using npm/pip/etc .. 
```

----------------------------------

## Project Automation

Project automation is dependency-free `make` targets that are scaffolded dynamically from project service definitions in the [containers/](containers/) folder, *i.e. from docker-compose files*.  Under the hood, scaffolding works via [`compose.mk`](https://robot-wranglers.github.io/compose.mk/overview/) and you can see a full reference [here](https://robot-wranglers.github.io/compose.mk/bridge/#target-scaffolding), but the gist of it is pretty simple.

The general pattern for command/control stuff is:

```bash
# Control individual services
$ make <namespace>.<service>.<compose_verb>

# Control all services
$ make <namespace>.<compose_verb>
```

Note that any container defined in the [containers/ folder](containers/) is a service in this sense, although [individual MCP subservers][#default-servers] may or may not be, since the point is [deal with those in aggregate](#core-mcp-servers).  In case a specific MCP-subserver isn't external and does not support stdio, then it probably **does** need to become a service.  Afterwards it automatically gets the capabilities in this section.  *(See for example `markitdown` in [containers/site.yml]*

### Service-Group Control

For us, `namespace` is always "workspace". So working with the whole stack might look like this:

```bash
# Start/restart the core MCP stack, in background.
$ make workspace.serve

# Start/restart the core MCP stack, in the foreground
$ make workspace.serve.fg

# Stop everything
$ make workspace.stop

# Dump the compose-config for all containers
$ make workspace.get_config
```

### Service Control

Some examples of working with individual services:

```bash
# Build/rebuild or start/stop individual components, foreground or background
$ make workspace.prompts.build workspace.prompts.up
$ make workspace.resources.stop workspace.resources.up.detach
$ make workspace.tools.build workspace.tools.up.detach
$ make workspace.combined_server.build workspace.combined_server.up.detach
..
```

And inference services:

```bash
# Local inference servers
$ make workspace.ollama.up
$ make workspace.lmstudio.up
$ make workspace.local_ai.up
..
```

### Container Debugging Shells

```bash
# Drop to shell and use mcpjungle/mcptools/inspector directly
$ make workspace.shell
⇒ workspace.shell (...)
root@workspace:/workspace# 

$ make workspace.ollama.shell
⇒ ollama.shell (...)
root@ollama:/workspace# 
```

### Typical Development Workflow

```bash
# Lint and format JSON, yaml, python files
$ make normalize validate

# Rebuilding and testing the main workspace container
$ make clean build serve test
```

### Workspace Status

When the `combined_server` is running, you can get the full system status like this:

```bash
$ make workspace.stat
{
  "containers": [
    "combined_server",
    "prompts",
    "resources",
    "tools"
  ],
  "servers": [
    "filesystem",
    "quickstart",
    "shell",
    "tasks"
  ],
  "tools": [
    "filesystem__read_file",
    "filesystem__read_text_file",
    "filesystem__read_media_file",
    "filesystem__read_multiple_files",
    "filesystem__write_file",
    "filesystem__edit_file",
    "filesystem__create_directory",
    "filesystem__list_directory",
    "filesystem__list_directory_with_sizes",
    "filesystem__directory_tree",
    "filesystem__move_file",
    "filesystem__search_files",
    "filesystem__get_file_info",
    "filesystem__list_allowed_directories",
    "quickstart__add",
    "shell__execute_command",
    "tasks__get_next_tasks",
    "tasks__mark_task_done",
    "tasks__add_task"
  ],
  "prompts": [
    "greet_user",
    "no-bullshit-protocol",
    "code-gen-protocol",
  ],
  "resources": [
  ]
}
```

### MCP Misc

In addition to the `workspace.*` API, there's a small `mcp.*` API for interrogating or manipulating the current project.

```bash
# List just the servers (similarly for tools/groups)
$ make mcp.list.servers
filesystem
quickstart
shell
tasks
```

### Resource Management

```bash
# Create a tool-group from an existing file (similarly for servers/prompts)
# Performs a check before moving forward so that it's idempotent.
$ make mcp.create.group/mcp/groups/demo.json
⇄ mcp.create.group // test-group.. ✗ missing 
  Tool Group test-group created successfully
  It is now accessible at the following streamable http endpoint:

      http://tools/v0/groups/test-group/mcp

# Or take advantage of volume-mounts and auto-reloading.
# Disable assets by moving them to disabled folder
# Re-enable by moving them back
$ mv mcp/prompts/demo.md mcp/prompts/disabled
$ mv mcp/prompts/disabled/demo.md mcp/prompts
```

----------------------------------

## Inference

The focus of this project is really on MCP, but as a PoC there's basic support for local inference.  See the [inference containers](containers/inference.yml) for details about versions.

### Ollama

```bash
# Start dockerized ollama
$ make workspace.ollama.up.detach

# Shell into the running ollama container
$ make workspace.ollama.exec.shell
```

Simple enough.  To script with the ollama CLI and create automation that's doing stuff like pre-pulling models, you can also consider using [container-dispatch](https://robot-wranglers.github.io/compose.mk/container-dispatch/).  For example if your model-setup target is called "provision", use `make workspace.ollama.exec/provision`.

### LMStudio

```bash
# This takes a while!
$ make lmstudio.build 

# Bring up a container that's running a headless version of LMStudio, foregrounded
$ make lmstudio.up

# Or backgrounded
$ make lmstudio.up.detach
```

The [lms cli](https://lmstudio.ai/docs/cli) is available, but using it on "remote" lmstudio servers is not supported for all subcommands.  You can use a command like this to drop into a debugging shell for the running server:

```bash
# Here you can use lms CLI directly
$ make workspace.lmstudio.exec.shell
root@lmstudio:/opt/lmstudio# 
```

As discussed in the ollama section, you can use automation that's leveraging [container-dispatch](https://robot-wranglers.github.io/compose.mk/container-dispatch/).  Some automation is available "from outside" the container, which is more convenient for bootstrapping tasks like loading models.

```bash
# equivalent to `lms status`
$ make lmstudio.lms.status

# equivalent to `lms load ..`
$ make lmstudio.lms.load/..
```

The `mcp.json` file details are [inlined config](containers/inference.yml), and preconfigured to connect to the [combined_server](#core-mcp), but you can also feel free to ignore MCP completely and just leverage your now portable and project-local lmstudio.

----------------------------------

## Motivation & Context

Sometimes it feels like the old "works on my machine!" problem is back with a vengance.  Seen any completely unverifiable blog posts about an "amazingly productive" custom setup for AI-assisted coding or deep-research or whatever this week?  Of course you have!  

* Did the blog post have a repository demonstrating the ideas?  If so..
* Was the repository useful, or was it actually tightly coupled to stuff that's out-of-band?
* Did the solution implicitly rely on `~user/.config_file`?
* Did the author assume you used a certain IDE?
* Was the solution tightly coupled to a personal choice of model/inference vendor?  
* Was the preferred model clearly specified and pinned at a version, was model choice something you could override?
* Did the author expect you to install and configure a whole language/framework stack to get started?
* If getting started is actually easy, did it feel like a blueprint that could scale into a system, or was it demoware?

**How did we get here?**  Forget about reproducible experimental design for a minute.. if your magical AI stack is so good, you're going to want to make it trivial for collaborators to use it.  Face it: you'll want to accept PRs from mere mortals at some point, if only to cut your own compute costs!

**What are your options?**  To solve the "works on my machine" problem, you can look to agent platforms, but many are semi-commercial, and it's unclear which have staying power.  Anyway, platforms and "studios" are usually *more like notebooks and less like pipelines* in the bad kind of way.  That is to say.. gradual resistance to automation while only configuration from a UI is allowed, and movement from simple yaml-in-repo description of dependencies towards another "hub" that starts to feel like an app-store.  Eventually you'll want something more stripped down for pipelines or the other from-scratch use-cases, like CI/CD, or the agentic equivalent for async PR workers, or for new (human) team members just getting started.

**Any other options?** Another option is [MCPB](https://github.com/anthropics/mcpb/tree/main), but as a standard it feels unfinished, and is currently defacto proprietary / tightly coupled to Claude.  MCPB-manifests ship as zip-archives that aren't easy to edit.  If you're going to ship a "bundle" that's hard to edit and convenient to use though.. why not solve dependency-management and foreign-frameworks at the same time with a docker-container that can run other docker-containers?  MCPB also focuses on servers, and so even for shipping a collection of flat prompts or templates, they require code.

**What could be better?** Beyond strict requirements for being reproducible and portable, it's hard to say exactly what that "workspace manifest" should look like, but a few things that would be nice to have are:

1. Local-first, in-repo, and platform agnostic, supporting but not requiring `OPENAI_API*`, `AWS_*`, etc
1. Zero host dependencies.  Everything is docker and pulled on demand (inference-wise as well as MCP)
1. Minimal open ports.  Leveraging docker networks as much as possible, because a workspace-manifest might be used with only small changes across several projects at once.
1. Project-local & (almost) stateless.  Although it's containerized, workspaces need the option to reinitialize from scratch at every bootstrap so that they can honor any changes to manifests.
1. Auto-reloading dev experience.  The whole system reinitializes in case of file system changes.

**Where are we headed?** Hosting inference or "rolling your own" locally might not be cheap or easy, but the systems we build *around* that inference might be most important part anyway.  Agent playgrounds and their protocols?  Probably the code-copilots & research assistants we want want are highly specific to the domain or project, they involve potentially many models, many frameworks, custom tools, custom RAG sources, supprting config like temperature-sliders, etc etc.  Per-project workspaces need to mix together various off-the-shelf components with more idiosyncratic site-specific ones, much like data-science projects, or similar to your project's CI/CD.  MCP is the obvious vehicle for doing all that at the system level in a way that still allows for being modular, yet staying flexible with choices at the inference layer or agent-framework layer.  But managing MCP, *especially interacting services/resources that might still be under development*, can be complicated.  The bad news is that in the limit, you do basically need to manage a fleet of microservices, but the good news is that since docker exists, this is basically a solved problem.

**Breaking:** [Skills.md](https://support.claude.com/en/articles/12512198-how-to-create-custom-skills) is another Claude-specific gambit that's using filesystem-based instructions + metadata + *optional* related scripts.  Nice format!  No more microservices?  But.. is it basically a collection of tagged MCP prompts, config resources, and servers, except with more lock-in since only Claude can use it?  About that "agent virtual environment" that runs the scripts.. how is it customized, and.. is it a container?  Aren't you going to need to ship/bundle dependencies for the tools/libraries those skills require/reference?  To what extent are we going to be stuck with skills in certain languages, or require Claude SDK's?  Are we going to do a whole "skills-hub" package management thing?  Other things that jump out are that skills are supposed to be composable, yet currently "skills may not reference other skills", quite a limiting factor compared to MCP servers that can just use boring old inheritance and composition with, you know, programming languages. It's unclear how we're going to extend skills, require skills, use remote skills, "deploy" reusable skills etc etc, and answering all these questions gets us most of the way back to MCP!  Ultimately skills seem like a really useful alternate "view" on the same data/code that MCP is covering, so if it catches on, maybe we'll see skill-to-MCP converters?  But that's another a project for another day ;)

**Wait, Is MCP actually dumb?**  Ah yes, this is a popular position too now.. those AI influencers really are pretty fickle aren't they?  And we're supposed to have extreme opinions on everything regardless of context (heh) or use-case.  Evaluating tech on merits instead of trends is hard, but worth it, so let's try.  First, many of the questions from the last section are also applicable here too.  Beyond that, the simplest bullet-proof argument that you need MCP is this:  

1. MCP is how you wrap/distribute/compose things related to tool-use. 
1. Tool-use is how you insist on an IO schema that LLMs must conform to. 
1. Schemas are how you combat hallucination, and how you can use AI in structured ways for things that it wasn't explicitly trained on.

That's just scratching the surface of what MCP is for.  You can throw all that away by rejecting MCP completely or by boiling tool-use down to just generating and running unstructured shell commands. But setting aside security issues or why you'd want to embrace more opportunities for hallucination instead of less.. shelling out for everything is perfect faith in the model's ability to generate correct bash for an infinite space of CLI surfaces. You've lost the ability to ever pivot to smaller/cheaper/local models, and now you're more addicted to external vendors and SOTA models, and you're worse-off with respect to uncommon toolchains.

----------------------------------

## Related Work

* https://github.com/neaigd/mcp_stack
* https://github.com/mcp-use/mcp-use
* https://localai.io/
* https://ollama.io/
* https://lmstudio.ai/
* https://hub.docker.com/r/mcp/everything
* https://github.com/coleam00/local-ai-packaged
* https://github.com/n8n-io/n8n
* https://collabnix.com/setting-up-ollama-models-with-docker-compose-a-step-by-step-guide/#Creating_a_Custom_Modelfile