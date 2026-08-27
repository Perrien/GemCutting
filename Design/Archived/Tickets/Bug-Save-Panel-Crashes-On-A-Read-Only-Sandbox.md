# Save Panel Crashes On A Read-Only Sandbox

Status: untriaged
Filed: 2026-08-26

The app target sets `ENABLE_USER_SELECTED_FILES = readonly` in both Debug and Release, so the sandbox
grants read but not write to files the owner picks. Any save panel — Save As, or the save prompt on
closing an edited document — fails with *"your app has the User Selected File Read entitlement but it
needs User Selected File Read/Write to display save panels"* and takes the app down with it. It needs
Read/Write, which is a capability change and therefore the owner's to make.
