## About 

Python files in this directory define MCP resources, loaded automatically when `resource_server` starts.  Python-backed resources use `fastmcp` conventions.

See the [upstream docs](https://github.com/jlowin/fastmcp?tab=readme-ov-file#resources--templates).

## Examples

Python style:

```python
from fastmcp import FastMCP

mcp = FastMCP("Demo 🚀")


# Static resource
@mcp.resource("config://version")
def get_version():
    return "2.0.1"


# Dynamic resource template
@mcp.resource("users://{user_id}/profile")
def get_profile(user_id: int):
    # Fetch profile for user_id...
    return {"name": f"User {user_id}", "status": "active"}
```
