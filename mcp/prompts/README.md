## About 

Markdown and python files in this directory are MCP prompts, loaded automatically when `prompts` starts.  Markdown prompts are "flat" and used as-is.  Python-backed prompts can take parameters and use `fastmcp` conventions.

See the [upstream docs](https://github.com/jlowin/fastmcp?tab=readme-ov-file#prompts).

## Examples

Python style:

```python
def summarize_request(text: str) -> str:
    """Generate a prompt asking for a summary."""
    return f"Please summarize the following text:\n\n{text}"
```