#!/bin/bash
# PreToolUse guard for read-only agents: blocks every Write, Edit and MultiEdit call.
echo "BLOCKED: this agent reports, it does not edit. Hand the finding back; another agent applies it." >&2
exit 2
