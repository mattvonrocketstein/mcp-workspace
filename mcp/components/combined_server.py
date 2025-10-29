"""
FastMCP server that does simple composition for given subservers.
Subservers can be specified as `host` or `host:port`, but protocol and url-path is implied.

USAGE: 
    MCP_COMBINED_PORT=80 MCP_SUBSERVERS=s1,s2,.. python combined_server.py
"""
import os
import sys
import logging

from rich import traceback
from fastmcp import FastMCP
from fastmcp.client import Client

traceback.install(show_locals=True)

from rich.console import Console

console = Console()
logging.basicConfig(level=logging.INFO)

MCP_COMBINED_PORT = int(os.environ.get('MCP_COMBINED_PORT','80'))
MCP_SUBSERVERS = os.environ.get('MCP_SUBSERVERS','') if len(sys.argv)<2 else sys.argv[1]
MCP_SUBSERVERS = MCP_SUBSERVERS.split(',') 
logging.warning(f"Subservers: {MCP_SUBSERVERS}")
MCP = FastMCP(name="Combined Server")

def mount(url): 
    MCP.mount(Client(f"http://{url}/mcp"), as_proxy=True)

for sub in MCP_SUBSERVERS:
    logging.warning(f"Loading subserver: {sub}")
    mount(sub)

if __name__ == "__main__":
    MCP.run(transport="http", host="0.0.0.0", port=MCP_COMBINED_PORT)
