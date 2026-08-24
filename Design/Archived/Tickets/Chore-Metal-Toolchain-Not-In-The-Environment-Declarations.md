# Metal Toolchain Not In The Environment Declarations

Status: open
Filed: 2026-08-24

Xcode 26.6 ships the Metal compiler as a separately downloaded component, so a machine that has not run
`xcodebuild -downloadComponent MetalToolchain` fails any build containing a `.metal` file with
`cannot execute tool 'metal' due to missing Metal Toolchain` — while `xcrun -f metal` still resolves,
which makes it look installed. `Design/Execution-Protocol.md`'s *Environment & toolchain* block does not
mention it. Noticed while executing `2-Cutting-Bench-App-Shell-2-Rough-In-The-Viewport` T4, which was
blocked on it.
