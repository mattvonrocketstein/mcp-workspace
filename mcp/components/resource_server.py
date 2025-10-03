"""
FastMCP server that loads resources from python-files or JSON
"""

import asyncio
import logging
import sys
from pathlib import Path

from fastmcp import FastMCP

loop = asyncio.get_event_loop()
mcp = FastMCP(name="Workspace Resource Server")
logging.basicConfig(level=logging.INFO)

ASSETS = {}
SUBS = {}
ASSET_DIR = (
    Path(sys.argv[1])
    if len(sys.argv) > 1
    else Path(__file__).parent.parent / "resources"
)


def load_resources():
    return {}


def load_python_assets(prompts={}, skip_list=[]) -> None:
    if not ASSET_DIR.exists():
        logging.critical(f"Asset-directory {ASSET_DIR} does not exist!")
        return
    for py_file in ASSET_DIR.glob("**/*.py"):
        basename = str(py_file.relative_to(ASSET_DIR).with_suffix(""))
        if any([basename in skip_list, str(py_file.parent).endswith("disabled")]):
            logging.info(f"  skipping {py_file}")
            continue
        logging.info(f"  looking for mcp servers in {basename}..")
        tmp = {}
        try:
            exec(open(py_file).read(), tmp)
        except (Exception,):
            logging.critical(
                f"error running {py_file}, cannot extract assets! skipping.."
            )
        else:
            sub_mcp = tmp.get("mcp", None)
            if sub_mcp is None:
                logging.warning(f"{py_file} does not define an mcp object! skipping..")
            else:
                SUBS[py_file] = sub_mcp


# Load assets at startup
logging.info(f"Loading resources from: {ASSET_DIR}")
ASSETS.update(load_resources())
# logging.info(f"Found {len(ASSETS)} markdown prompts")
logging.info(f"Loading python-backed resources from: {ASSET_DIR}")
load_python_assets()
logging.info(f"Found {len(ASSETS)} python files")


@mcp.prompt()
def list_resources() -> list[str]:
    """
    Lists all available resources.
    """
    return list(ASSETS.keys())


async def setup():
    logging.info("Building server..")
    for fname, sub in SUBS.items():
        logging.info(f"  importing {fname}: {sub}")
        await mcp.import_server(sub)


if __name__ == "__main__":
    asyncio.run(setup())
    mcp.run(transport="http", host="0.0.0.0", port=80)
