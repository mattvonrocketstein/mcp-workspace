"""
FastMCP subserver demo, contributing prompts
"""

from fastmcp import FastMCP

mcp = FastMCP(name="Prompt Demo")


@mcp.prompt()
def greet_user(name: str, style: str = "friendly") -> str:
    """
    Generate a greeting prompt.
    """
    styles = {
        "friendly": "Please write a warm, friendly greeting",
        "formal": "Please write a formal, professional greeting",
        "casual": "Please write a casual, relaxed greeting",
    }
    return f"{styles.get(style, styles['friendly'])} for someone named {name}."
