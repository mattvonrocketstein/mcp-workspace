# Only used for CI/CD upstream[1] to create/push the main container[2]. 
# (Safe to remove this file if you've forked [1] as template repository)
#
# The real work to assemble this image is done in containers/mcp.yml, usually triggered by `make build`.
#
# [1] https://github.com/mattvonrocketstein/mcp-workspace
# [2] ghcr.io/mattvonrocketstein/mcp-workspace:latest
#
FROM mcp.local:workspace