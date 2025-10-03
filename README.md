## About

This is a template repository for building and bundling MCP stacks.  The emphasis is on containers, and folder-based, in-repo configuration, with a focus on local-first workflows.  You can use it to work with groups of related MCP servers using [mcpjungle](https://github.com/mcpjungle/MCPJungle) and [fastmcp](https://gofastmcp.com/).  Besides stacking together MCP servers, it can help with plug-and-play for related assets like *tool-groups*, *prompt templates*, and *resources*.

Making MCP experimentation and bundling easy is the primary goal, but there's also some boilerplate and support automation for containerized inference engines, including `ollama`, `lmstudio`, and `local-ai`.

**Why?** There's lots of frameworks for agentic workflows, but **reproducible and portable manifests for AI stack configurations**, i.e. "workspaces", is something that is conspicuously missing.  See the [Motivation & Context](#motivation-context) section at the end of these docs for long-format answer, or read on to just jump in.

----------------------------------

## General Usage

There are two main ways to use this project:

**Use the published [docker image](#docker-image) or extend it.**  By default, the registry includes tool-servers for things like filesystem / shell / git access, and basic RAG tools, but you can wipe those out and add others instead.  This approach is good if you're looking to bundle/ship a related group of services, but don't want separate images for each, and don't want to push the configuration/installation work onto users.

**Fork this repository and work in-place,** structuring your own experiments around the [project layout](#project-layout) and leveraging the existing [project automation](#project-automation).  This approach is more useful if you need an AI stack with multiple components, but also don't really need to ship that stack anywhere. (Is your stack "project local", and tightly coupled to the code/data that it lives near?)  Besides development *with* help from MCP servers, this approach is also useful for active development *on* related MCP servers.

----------------------------------

## How it Works

### Core MCP Servers
<a name='core-mcp-servers'></a>
<a name='core-mcp'></a>

This project defines a `prompts` server, a `tools` server, and a `resources` server which are exposed as a single `combined_server`.  Each internal server expects folder-based configuration, and is wrapped with a supervisor that restarts automatically if filesystem config changes.  By default, each server runs in a container, each is launched from [main workspace image](#main-image).

* **`tools` server** *(internal)*: Starts `mcpjungle`, loading assets from [mcp/tools/](mcp/tools) and [mcp/groups/](mcp/groups).

* **`prompts` server** *(internal)*: Starts a `fastmcp` server, automatically loading both markdown-files or prompts-in-python from [mcp/prompts/](mcp/prompts). *( [code](mcp/components/prompt_server.py) )*

* **`resources` server** *(internal)*: Starts a `fastmcp` server, loading JSON-schema or fastmcp-style resources in python from [mcp/resources/](mcp/resources). *( [code](mcp/components/resource_server.py) )*

* **`combined_server`** *(optionally exposed to the host)*: Using [fastmcp server composition](https://fastmcp.wiki/en/servers/composition#server-composition), `combined_server` binds all of the others together in the same namespace on a single dynamic server.  To avoid the additional complexity of guessing where everything is, aggregation is naive: *No prefixes are used for namespacing subserver assets*, so beware name collisions! *( [code](mcp/components/combined_server.py) )*

**`mcpjungle`** works as a tool-registry that's language and framework agnostic, allowing you to directly run (or reference URLs for) other MCP subservers.  Typically subservers use stdio transport, and subservers may be launched as usual with npx, uvx, docker, etc.  The upside is JSON config that's familiar, plus it's an aggregator that's indifferent about what kind of servers it can combine.  Typically though subserver config must be *pushed* to the mcpjungle-server from the mpcjungle client, rather than the server loading it at startup.  This project adds flexible bootstrap and auto-reload-on-file-changes automation that can apply/update all the relevant config in the [associated folders](#project-layout).

**`fastmcp`** is used for prompts and resources because [upstream support for prompt/resource management in mcpjungle](https://github.com/mcpjungle/MCPJungle/issues/73) isn't done yet.  Both the `prompts` and `resources` servers work in a similar way, automatically loading python-backed asset descriptions or "flat" assets from [associated folders](#project-layout).  

A few things other things that are worth nothing:

1. *Technically,* there's no limits on the "kinds" that `fastmcp` can load in [subfolders](#project-layout), so the prompt-server and the resource-server can both describe general MCP resources (including  servers, prompts, etc).  (In fact, the prompt-server defines a `list_prompts` tool, and the resources-server defines a `list_resources` tool.) Prompts/resources are separated anyway for convenience and customization.  This leaves open the possibility of deploying them separately, or adding new processes for automatically converting other file types to managed MCP resources.
1. *Although slicing assets by tags* is still [under discussion in the MCP spec](https://github.com/modelcontextprotocol/modelcontextprotocol/issues/1300) it's already [supported for fastmcp kinds](https://gofastmcp.com/servers/prompts#param-tags) and supported in general via [mcpjungle groups](https://github.com/mcpjungle/MCPJungle?tab=readme-ov-file#tool-groups).

To bring up all services use `make serve`.  Fine-grained command/control for the individual servers is also available; see [the rest of the automation docs here](#project-automation).

----------------------------------

### Workspace Image
<a name=main-image></a><a name=workspace-container></a>

All servers are instances of the same image, i.e. `mcp.local:workspace` as defined in [containers/mcp.yml](containers/mcp.yml).  *(If you're working with a repo clone, you can build this with `make build`. See [this section](#docker) for more discussion about using the published image.)*

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

When the [workspace image](#workspace-image) is built, everything goes to `/opt/mcp`.  Because mcp-workspace is stateless and configured from scratch at every bootstrap, you can override / extend resources like the [default builtin servers](#docker-image) by overriding the volume for `/opt/mcp/tools`.

Containers for `prompts`, `resources`, `tools`, and `combined_server` are all defined in [containers/mcp.yml](containers/mcp.yml).  These extend the same base, but provide different entrypoints.  See [containers/inference.yml](containers/inference.yml) for ollama/lmstudio, see [containers/site.yml](containers/site.yml) for other ancillary containers.

----------------------------------

## What's in the Box?
<a name=default-servers></a>

Default servers include:

* **filesystem access:** [npm://modelcontextprotocol/server-filesystem](https://www.npmjs.com/package/@modelcontextprotocol/server-filesystem)
* **tasks management:** [github://flesler/mcp-tasks](https://github.com/flesler/mcp-tasks) 
* **shell access:** [pypi://mcp-server-shell](https://pypi.org/project/mcp-server-shell/)
* **markdown convert/extract:** [github://microsoft/markitdown-mcp](https://github.com/microsoft/markitdown/tree/main/packages/markitdown-mcp)

Currently evaluating:

* [gh://idosal/git-mcp](https://github.com/idosal/git-mcp)
* [gh://arabold/docs-mcp-server](https://github.com/arabold/docs-mcp-server)
* [gh://modelcontextprotocol/mcp-server-git](https://github.com/modelcontextprotocol/servers/tree/main/src/git), [@pypi](https://pypi.org/project/mcp-server-git/)
* [gh://awwaiid/mcp-server-taskwarrior](https://github.com/awwaiid/mcp-server-taskwarrior) [npm://mcp-server-taskwarrior](https://www.npmjs.com/package/mcp-server-taskwarrior)
* Basic RAG with minimal dependencies is hard to find.. create an issue if you have any ideas

## Using the Docker Image
<a name=docker-image></a>

```bash
$ docker run \
  -it -v /var/run/docker.sock:/var/run/docker.sock \
  ghcr.io/mattvonrocketstein/mcp-workspace:latest help
```

Or from a Dockerfile:

```Dockerfile
FROM ghcr.io/mattvonrocketstein/mcp-workspace:latest
...
```

Or with docker-compose:

```yaml
...
```

----------------------------------

## Project Automation

Project automation is dependency-free `make` targets that are scaffolded dynamically from project service definitions in the [containers/](containers/) folder, *i.e. from docker-compose files*.  Under the hood, scaffolding works via [`compose.mk`](#) and you can see a full reference [here](https://robot-wranglers.github.io/compose.mk/bridge/#target-scaffolding), but the gist of it is pretty simple.

The general pattern for command/control stuff is:

```bash
# Control individual services
$ make <namespace>.<service>.<compose_verb>

# Control all services
$ make <namespace>.<compose_verb>

# Slice services by compose-profiles
$ make <namespace>.profile/<compose_verb>
```

Note that any container defined in the [containers/ folder](containers/) is a service in this sense, although [individual MCP subservers][#default-servers] may or may not be, since the point is [deal with those in aggregate](#core-mcp-servers).  In case a specific MCP-subserver isn't external and does not support stdio, then it probably **does** need to become a service.  *(Afterwards it automatically gets the capabilities in this section; see `markitdown` in [containers/site.yml])*

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
    "list_prompts",
    "test-prompt-1",
    "greet_user",
    "list_resources"
  ],
  "resources": [
    "get_version"
  ]
}
```

### MCP Misc

In addition to the `workspace.*` API, there's a small `mcp.*` for interrogating or manipulating the current project.

```bash
# List just the servers (similarly for tools/groups)
$ make mcp.list.servers
filesystem
quickstart
shell
tasks
```

### Resource Management

Performs a check before moving forward so that it's idempotent.

```bash
# Create a tool-group from an existing file (similarly for servers/prompts)
$ make mcp.create.group/mcp/groups/demo.json
⇄ mcp.create.group // test-group.. ✗ missing 
  Tool Group test-group created successfully
  It is now accessible at the following streamable http endpoint:

      http://mcp_tools:8080/v0/groups/test-group/mcp

# Or take advantage of volume-mounts and auto-reloading.
# Disable assets by moving them to disabled folder
# Re-enable by moving them back
$ mv mcp/prompts/demo.md mcp/prompts/disabled
$ mv mcp/prompts/disabled/demo.md mcp/prompts
```

----------------------------------

## Inference

The focus of this project is really on MCP, but as a PoC, there's basic support for local inference.  See the [inference containers](containers/inference.yml) for details about versions.

### Ollama

```bash
$ make workspace.ollama.up
```

### LMStudio



```bash
# Bring up a container that's running a headless version of LMStudio
$ make workspace.lmstudio.up
```

The [lms cli](https://lmstudio.ai/docs/cli) is available, but using it on "remote" lmstudio servers is not supported for all subcommands.  You can use a command like this to drop into a debugging shell for the running server:

```bash
# Here you can use lms CLI directly
$ make workspace.lmstudio.exec/io.bash
root@lmstudio:/opt/lmstudio# 
```

Some automation is available "from outside", which is more convenient for bootstrapping tasks like loading models.

```bash
$ make lmstudio.lms.status

$ make lmstudio.lms.load/..
```

The `mcp.json` file details are [inlined config](containers/inference.yml), and preconfigured to connect to the [combined_server](#core-mcp).

### Local-AI

Documentation coming soon.

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

**How did we get here?**  Forget about reproducible experimental design for a minute.. if your stack is so good, you're going to want to make it trivial for collaborators to use it.  (Face it: you'll need to accept PRs from mere mortals at some point if only to cut your own compute costs!)  

**What are your options?**  To solve the "works on my machine" problem, you can look to agent platforms, but many are semi-commercial, and it's unclear which have staying power.  Anyway, "platforms or studios" are usually *more like notebooks and less like pipelines* in the bad kind of way, with gradual resistance to automation while only configuration from a UI is allowed, and movement from simple yaml-in-repo description of dependencies towards another "hub" that starts to feel like an app-store.  Eventually you'll want something more stripped down for pipelines or the other from-scratch use-cases, like CI/CD, or the agentic equivalent for async PR workers, or for new human team members.

**Any other options?** Another option is [MCPB](https://github.com/anthropics/mcpb/tree/main), but as a standard it feels unfinished, and is currently defacto proprietary / tightly coupled to Claude.  MCPB-manifests ship as zip-archives that aren't easy to edit.  If you're going to ship a "bundle" that's hard to edit and convenient to use though.. why not solve dependency-management and foreign-frameworks at the same time with a docker-container that can run other docker-containers?  MCPB also focuses on servers, and so even for shipping a collection of flat prompts or templates, they require code.

**What could be better?** Beyond strict requirements for being reproducible and portable, it's hard to say exactly what that "workspace manifest" should look like, but a few things that would be nice to have are:

1. Local-first, in-repo, and platform agnostic, supporting but not requiring `OPENAI_API*`, `AWS_*`, etc
1. Zero host dependencies.  Everything is docker and pulled on demand (optionally [including inference](#inference))
1. Minimal open ports.  Leveraging docker networks as much as possible, because a workspace-manifest might be used with only small changes across several projects at once.
1. Project-local / stateless.  Although it's containerized, workspaces need the option to reinitialize from scratch at every bootstrap so that they can honor any changes to manifests.
1. Auto-reloading dev experience.  The whole system reinitializes in case of file system changes.

**Where are we headed?** Hosting inference or "rolling your own" locally might not be cheap or easy, but the systems we build *around* that inference might be most important part anyway.  Agent playgrounds and their protocols?  Probably the code-copilots & research assistants we want want are highly specific to the domain or project, they involve potentially many models, many frameworks, custom tools, custom RAG sources, supprting config like temperature-sliders, etc etc.  Per-project workspaces need to mix together various off-the-shelf components with more idiosyncratic site-specific ones, much like data-science projects, or similar to your project's CI/CD.  MCP is the obvious vehicle for doing all that at the system level in a way that allows for being modular, yet staying flexible with choices at the inference layer or agent-framework layer.  But managing MCP, *especially interacting services/resources that might still be under development*, quickly means managing a fleet of microservices.

**Breaking:** [Skills.md](https://support.claude.com/en/articles/12512198-how-to-create-custom-skills) is another Claude-specific gambit that's using filesystem-based instructions + metadata + *optional* related scripts.  Nice format!  No more microservices?  But.. is it basically a collection of tagged MCP prompts, config resources, and servers, except with more lock-in since only Claude can use it?  About that "agent virtual environment" that runs the scripts.. how is it customized, and.. is it a container?  To what extent are we going to be stuck with skills in certain languages, or require Claude SDK's?  Are we going to do a whole "skills-hub" package management thing?  Other things that jump out are that skills are supposed to be composable, yet currently "skills may not reference other skills", and that it's unclear how we're going to extend skills, require skills, use remote skills, "deploy" reusable skills etc etc, and answering all these questions gets us most of the way back to MCP!  Ultimately skills seem like a really useful alternate "view" on the same data/code that MCP is covering, so if it catches on, maybe we'll see [skill-to-MCP converters?](#skill-converter)


----------------------------------

## Related Work

* https://github.com/neaigd/mcp_stack
* https://localai.io/
* https://ollama.io/
* https://lmstudio.ai/
* https://hub.docker.com/r/mcp/everything
* https://github.com/coleam00/local-ai-packaged
* https://github.com/n8n-io/n8n