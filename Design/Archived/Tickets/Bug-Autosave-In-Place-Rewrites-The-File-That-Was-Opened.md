# Autosave In Place Rewrites The File That Was Opened

> **Stale claim — trust the code.** This ticket says *"the read-only sandbox is the only thing
> preventing it today."* That is no longer true: file access was changed to read/write on 2026-08-27, so
> nothing in the app prevents an edit to an opened pattern from writing back to it. Closed as won't-fix
> — the behaviour is accepted, and untouched copies of the four patterns are kept outside the app
> instead.

Status: untriaged
Filed: 2026-08-26

The document autosaves in place, so an edit to an open pattern writes back to the file it came from with
no explicit save. Opening one of the four patterns in `Design/Patterns/` and changing anything therefore
rewrites external ground truth, which the protocol's guardrails forbid. The read-only sandbox is the only
thing preventing it today, and `Bug-Save-Panel-Crashes-On-A-Read-Only-Sandbox` asks for that to be lifted.
