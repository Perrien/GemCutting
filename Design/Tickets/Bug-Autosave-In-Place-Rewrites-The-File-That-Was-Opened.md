# Autosave In Place Rewrites The File That Was Opened

Status: untriaged
Filed: 2026-08-26

The document autosaves in place, so an edit to an open pattern writes back to the file it came from with
no explicit save. Opening one of the four patterns in `Design/Patterns/` and changing anything therefore
rewrites external ground truth, which the protocol's guardrails forbid. The read-only sandbox is the only
thing preventing it today, and `Bug-Save-Panel-Crashes-On-A-Read-Only-Sandbox` asks for that to be lifted.
