#!/usr/bin/env python3
"""Talk to the Figma desktop MCP server over its local HTTP endpoint.

Usage:
    figma.py probe
    figma.py meta      <nodeId>
    figma.py context   <nodeId>
    figma.py vars      <nodeId>
    figma.py shot      <nodeId> <outPath.png>
    figma.py raw       <toolName> <argsJSON>

`probe` runs the MCP handshake only and prints the session id: it is the
liveness check to run before any other call. The node must live in the Figma
tab that is currently active on screen, and nodeId must match ^\\d+[:-]\\d+$.
Instance-scoped ids like "I31:5401;292:6308" are rejected by the server --
query the top-level instance instead.

`clientLanguages`/`clientFrameworks` do not change the output language: the
desktop server returns React + Tailwind as a structural reference whatever is
passed; the values only select Code Connect mappings on the remote server.
"""
import base64
import json
import sys
import urllib.error
import urllib.request

URL = "http://127.0.0.1:3845/mcp"
COMMON = {"clientLanguages": "kotlin", "clientFrameworks": "compose"}
SETUP_HINT = (
    "Figma desktop MCP server is not reachable at " + URL + ".\n"
    "Open the design file in the Figma desktop app, switch to Dev Mode (Shift+D)\n"
    "and turn on 'Enable desktop MCP server' in the inspect panel, then retry."
)


def _request(body, sid=None):
    req = urllib.request.Request(URL, data=json.dumps(body).encode(), method="POST")
    req.add_header("Content-Type", "application/json")
    req.add_header("Accept", "application/json, text/event-stream")
    if sid:
        req.add_header("mcp-session-id", sid)
    return req


def _handshake():
    init = {
        "jsonrpc": "2.0", "id": 1, "method": "initialize",
        "params": {
            "protocolVersion": "2024-11-05", "capabilities": {},
            "clientInfo": {"name": "compose-figma-verify", "version": "1"},
        },
    }
    resp = urllib.request.urlopen(_request(init), timeout=30)
    sid = resp.headers.get("mcp-session-id")
    for raw in resp:
        if raw.startswith(b"data: "):
            break
    resp.close()
    urllib.request.urlopen(
        _request({"jsonrpc": "2.0", "method": "notifications/initialized"}, sid),
        timeout=10,
    ).close()
    return sid


def call(tool, args, timeout=120):
    sid = _handshake()
    body = {"jsonrpc": "2.0", "id": 9, "method": "tools/call",
            "params": {"name": tool, "arguments": args}}
    stream = urllib.request.urlopen(_request(body, sid), timeout=timeout)
    for raw in stream:
        line = raw.decode().rstrip()
        if line.startswith("data: "):
            return json.loads(line[6:])
    return {}


def probe():
    sid = _handshake()
    print(f"ok  session={sid}  url={URL}")
    return 0


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        return 1

    cmd = sys.argv[1]
    tools = {"meta": "get_metadata", "context": "get_design_context",
             "vars": "get_variable_defs", "shot": "get_screenshot"}

    try:
        if cmd == "probe":
            return probe()
        if cmd == "raw" and len(sys.argv) >= 4:
            result = call(sys.argv[2], json.loads(sys.argv[3]))
        elif cmd in tools and len(sys.argv) >= 3:
            result = call(tools[cmd], dict(COMMON, nodeId=sys.argv[2]))
        else:
            print(__doc__)
            return 1
    except urllib.error.URLError as error:
        print(SETUP_HINT, file=sys.stderr)
        print(f"({error})", file=sys.stderr)
        return 2

    for content in result.get("result", {}).get("content", []):
        if content.get("type") == "text":
            print(content["text"])
        elif content.get("type") == "image" and cmd == "shot":
            with open(sys.argv[3], "wb") as handle:
                handle.write(base64.b64decode(content["data"]))
            print(f"saved {sys.argv[3]}")
    if "error" in result:
        print("ERROR", json.dumps(result["error"])[:600])
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
