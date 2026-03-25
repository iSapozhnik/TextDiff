# Agent Guidelines

## Implementation principles
- While implementing features, prioritize the KISS (Keep It Simple, Stupid) and YAGNI (You Aren't Gonna Need It) principles to avoid unnecessary complexity.
- Maintain separation of concerns and adhere to the Single Responsibility Principle so each component has a clear, focused purpose.
- Keep helper types in their own files/folders instead of nesting multiple classes/structs inside a single file.

## SwiftUI workflow
- When implementing, reviewing, or refactoring SwiftUI Views and ViewModels, always use the `swiftui-expert-skill` guidance.
- SwiftUI views should always include `#Preview` with a few state configurations.

## Guardrails (Behavior & Dependencies)
- **When in doubt, STOP and ASK before proceeding.**

## Token-efficient build output
- Always pipe Xcode/Swift build logs through [`xcsift`](https://github.com/ldomaradzki/xcsift) to keep transcripts small and structured.
- Remember to redirect stderr to stdout (`2>&1`) so `xcsift` sees the full log stream.
- Unless explicitly requested by the user, run `xcodebuild` only with `-configuration Debug` (do not run Release builds).

### Common commands
- Basic build: `xcodebuild -project <project> -scheme <scheme> -configuration Debug build 2>&1 | xcsift`
- Run tests + coverage: `xcodebuild test -enableCodeCoverage YES 2>&1 | xcsift --coverage`
- Show warnings explicitly: `xcodebuild build 2>&1 | xcsift --print-warnings`
- Quiet success noise: `xcodebuild build 2>&1 | xcsift --quiet`
- Swift Package Manager workflows: `swift build 2>&1 | xcsift` and `swift test 2>&1 | xcsift`

Use the flags above (e.g., `--coverage-details`, `--coverage-path`) as needed, but keep the default JSON output unless the user asks for more detail.

## Fast file search
- Use [`fd`](https://github.com/sharkdp/fd) for locating files—it's a fast, user-friendly alternative to `find`.
- Typical commands: `fd src` (search everywhere for "src"), `fd -e ts foo` (look for TypeScript files matching "foo").
- Prefer `fd` for repo-wide file discovery unless the task explicitly requires another tool.

## Code search
- Use [`ripgrep`](https://github.com/BurntSushi/ripgrep) (`rg`) for searching within files—it is much faster than grep/ack/ag, respects `.gitignore`, and has smart defaults.
- Typical commands: `rg "TODO"` (find TODOs), `rg -n --glob '!dist' pattern.swift` (search with line numbers while excluding `dist`).

<!-- BACKLOG.MD MCP GUIDELINES START -->

<CRITICAL_INSTRUCTION>

## BACKLOG WORKFLOW INSTRUCTIONS

This project uses Backlog.md MCP for all task and project management activities.

**CRITICAL GUIDANCE**

- If your client supports MCP resources, read `backlog://workflow/overview` to understand when and how to use Backlog for this project.
- If your client only supports tools or the above request fails, call `backlog.get_workflow_overview()` tool to load the tool-oriented overview (it lists the matching guide tools).

- **First time working here?** Read the overview resource IMMEDIATELY to learn the workflow
- **Already familiar?** You should have the overview cached ("## Backlog.md Overview (MCP)")
- **When to read it**: BEFORE creating tasks, or when you're unsure whether to track work

These guides cover:
- Decision framework for when to create tasks
- Search-first workflow to avoid duplicates
- Links to detailed guides for task creation, execution, and finalization
- MCP tools reference

You MUST read the overview resource to understand the complete workflow. The information is NOT summarized here.

</CRITICAL_INSTRUCTION>

<!-- BACKLOG.MD MCP GUIDELINES END -->
