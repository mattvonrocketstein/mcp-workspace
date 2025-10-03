"""
FastMCP server that loads all markdown files from a directory as prompt resources.
Additionally loads any FastMCP instances defined by any python files in the same directory.
"""

import asyncio
import logging
import sys
from pathlib import Path

from fastmcp import FastMCP
from rich.console import Console
from rich.traceback import install

# This will automatically format all exceptions in your program
install(show_locals=True)
console = Console()

loop = asyncio.get_event_loop()
mcp = FastMCP(name="Workspace Prompt Server")

logging.basicConfig(level=logging.INFO)

# Directory to load markdown files from
ASSET_DIR = Path(sys.argv[1])
SUBS, PROMPTS = {}, {}


def load_markdown_prompts(prompts={}, skip_list=["README"]):
    """
    Load all markdown files from the directory as prompts.
    """
    logging.info(f"Loading markdown prompts from: {ASSET_DIR}")
    if not ASSET_DIR.exists():
        logging.critical(f"Prompt-directory {ASSET_DIR} does not exist")
        return prompts
    for md_file in ASSET_DIR.glob("**/*.md"):
        # Use relative path as prompt name (without .md extension)
        prompt_name = str(md_file.relative_to(ASSET_DIR).with_suffix(""))
        if any([prompt_name in skip_list, str(md_file.parent).endswith("disabled")]):
            logging.warning(f"  skipped disabled prompt: {prompt_name}")
            continue
        if prompt_name in prompts:
            logging.warning(f"  skipped duplicate prompt: {prompt_name}")
            continue
        else:
            content = md_file.read_text(encoding="utf-8")
            prompts[prompt_name] = content
            logging.info(f"  discovered markdown prompt: {prompt_name}")
    return prompts


def load_python_assets(subs={}, skip_list=[]) -> None:
    logging.info(f"Loading MCP-servers from: {ASSET_DIR}")
    if not ASSET_DIR.exists():
        logging.critical(f"Prompt-directory {ASSET_DIR} does not exist!")
        return
    for py_file in ASSET_DIR.glob("**/*.py"):
        basename = str(py_file.relative_to(ASSET_DIR).with_suffix(""))
        if basename in skip_list:
            continue
        logging.info(f"  looking for mcp servers in {basename}..")
        tmp = {}
        try:
            exec(open(py_file).read(), tmp)
        except (Exception,) as exc:
            logging.critical(f"{py_file} :: \n{exc}")
            console.print_exception(show_locals=True)
            logging.critical(f"cannot extract MCP from {py_file}! skipping..")
        else:
            sub_mcp = tmp.get("mcp", None)
            if sub_mcp is None:
                logging.warning(
                    f"{py_file} does not define an `mcp` object! skipping.."
                )
            else:
                subs[py_file] = sub_mcp
    logging.info(f"Found {len(subs)} python files")
    return subs


# Load prompts/subservers at startup
PROMPTS.update(load_markdown_prompts())
logging.info(f"Found {len(PROMPTS)} markdown prompts")
SUBS.update(load_python_assets())


@mcp.prompt()
def list_prompts() -> list[str]:
    """
    Lists all available markdown prompts.
    """
    return list(PROMPTS.keys())


# Dynamically create prompt-assets for each markdown file,
# creating a closure to capture the content
for prompt_name, prompt_content in PROMPTS.items():

    def create_prompt_handler(content: str):
        def handler() -> str:
            return content

        return handler

    handler = create_prompt_handler(prompt_content)
    handler.__name__ = prompt_name.replace("/", "_").replace("-", "_")
    mcp.prompt(
        name=prompt_name, tags=["markdown"], description=f"Prompt from {prompt_name}.md"
    )(handler)


async def setup():
    """Import without prefix - components keep original names"""
    logging.info("Building server..")
    for fname, sub in SUBS.items():
        logging.info(f"  importing {fname}: {sub}")
        await mcp.import_server(sub)


if __name__ == "__main__":
    asyncio.run(setup())
    mcp.run(transport="http", host="0.0.0.0", port=80)
