"""
Demo Resources
For an overview and compare/contrast on MCP tools vs MCP resources, see
https://medium.com/@laurentkubaski/mcp-resources-explained-and-how-they-differ-from-mcp-tools-096f9d15f767
"""

from fastmcp import FastMCP

mcp = FastMCP("Resource Demo")


@mcp.resource("config://version")
def get_version():
    return "2.0.1"


# Dynamic resource template
@mcp.resource("users://{user_id}/profile")
def get_profile(user_id: int):
    """A real version would fetch profile for user_id..."""
    return {"name": f"User {user_id}", "status": "active"}
