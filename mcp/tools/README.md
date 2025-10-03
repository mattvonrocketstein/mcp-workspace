## About 

JSON files in this directory are mcp server descriptions used by mcpjungle , loaded automatically when `tools` starts.

See the [upstream docs](https://github.com/mcpjungle/MCPJungle#registering-streamable-http-based-servers).

## Examples

STDIO 

```json 
{
  "name": "<name of your mcp server>",
  "transport": "stdio",
  "description": "<description>",
  "command": "<command to run the mcp server, eg- 'npx', 'uvx'>",
  "args": ["arguments", "to", "pass", "to", "the", "command"],
  "env": {
    "KEY": "value"
  }
}
```

HTTP

```json
{
  "name": "<name of your mcp server>",
  "transport": "streamable_http",
  "description": "<description>",
  "url": "<url of the mcp server>",
  "bearer_token": "<optional bearer token for authentication>"
}
```