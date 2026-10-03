---
description: "Rules for replacing legacy menu method wrappers with 4D standard actions in menus.json — eliminating unnecessary project methods like m_Quit that wrap single built-in commands"
applyTo: "demo/**/menus.json,demo/**/Methods/*.4dm"
---

# 4D Menu Standard Actions — Agent Rules

## Overview

These instructions describe how to replace legacy menu method wrappers with 4D standard actions in HDI projects. The goal is to eliminate unnecessary project methods that wrap single built-in commands and instead use the `"action"` property on menu items in `menus.json`.

---

## The Problem

A common legacy pattern creates a project method (e.g., `m_Quit`) that wraps a single command (e.g., `QUIT 4D`) and assigns it to a menu item via the `"method"` property in `menus.json`.

**Example of the outdated pattern:**

`m_Quit.4dm`:
```4d
//%attributes = {}
QUIT 4D:C291
```

`menus.json`:
```json
{
	"title": ":xliff:CommonMenuItemQuit",
	"method": "m_Quit",
	"shortcutAccel": true,
	"shortcutKey": "Q"
}
```

---

## Why It Is Wrong

1. **Unnecessary indirection.** A one-line wrapper method adds a layer that serves no purpose.
2. **Bypasses platform integration.** Standard actions like `quit` integrate with the platform's native behaviour. On macOS, the Quit item is automatically moved to the application menu per Human Interface Guidelines. A method-based approach loses this.
3. **No automatic enable/disable.** Standard actions are automatically enabled or disabled by 4D based on context. A method-based menu item is always enabled, which can lead to incorrect behaviour.
4. **Pollutes the method namespace.** A one-line wrapper is dead weight in the project's method list and the Run > Method... dialog.

---

## The Fix

1. Replace `"method"` with `"action"` on the menu item in `menus.json`, using the appropriate standard action string.
2. Delete the wrapper method `.4dm` file.
3. Preserve all other properties (`"title"`, `"shortcutAccel"`, `"shortcutKey"`, etc.).

**Before (wrong):**
```json
{
	"title": ":xliff:CommonMenuItemQuit",
	"method": "m_Quit",
	"shortcutAccel": true,
	"shortcutKey": "Q"
}
```

**After (correct):**
```json
{
	"title": ":xliff:CommonMenuItemQuit",
	"action": "quit",
	"shortcutAccel": true,
	"shortcutKey": "Q"
}
```

And `m_Quit.4dm` is **deleted**.

---

## Common Standard Actions

These standard action strings replace the most common single-command wrapper methods:

| Standard Action | Replaces Method Wrapping | Notes |
|----------------|--------------------------|-------|
| `quit` | `QUIT 4D` | Graceful quit with platform integration |
| `cut` | Cut clipboard code | Cut to clipboard |
| `copy` | Copy clipboard code | Copy to clipboard |
| `paste` | Paste clipboard code | Paste from clipboard |
| `selectAll` | Select all code | Select all |
| `undo` | Undo code | Undo last action |
| `redo` | Redo code | Redo last undone action |

---

## When to Use `"action"` vs `"method"`

| Use Case | Correct Approach |
|----------|-----------------|
| Menu item performs a single built-in operation (quit, cut, copy, paste, etc.) | Use `"action"` with the standard action string. Delete the wrapper method. |
| Menu item performs custom, project-specific logic | Use `"method"` referencing a project method. |
| Menu item needs standard enable/disable behaviour + custom code | Use both `"action"` and `"method"`. 4D uses the action for enable/disable but executes the method. |

### Combining `"action"` and `"method"`

From the 4D documentation:

> You can assign both a standard action and a project method to a menu command. In this case, the standard action is never executed; however, 4D uses this action to enable/disable the menu command according to the current context and to associate a specific operation with it according to the platform. When a menu command is deactivated, the associated project method cannot be executed.

---

## Audit Procedure

1. **Scan `menus.json`** for menu items with a `"method"` property.
2. **Read each referenced method file** (`Project/Sources/Methods/{name}.4dm`).
3. **If the method body is a single command** that corresponds to a standard action, replace `"method"` with `"action"` and delete the `.4dm` file.
4. **If the method contains custom logic**, keep `"method"`. Optionally add `"action"` alongside it for enable/disable management.

---

## Anti-Patterns

### ❌ Method wrappers for standard operations

```4d
// WRONG — m_Quit.4dm wrapping a single command
QUIT 4D:C291
```

Delete the file. Use `"action": "quit"` instead.

### ❌ Keeping orphaned method files

After removing `"method"` from the menu item, always delete the corresponding `.4dm` file. Orphaned methods clutter the project.

### ❌ Leaving stale references in `folders.json`

Deleting a wrapper method's `.4dm` file is not enough — 4D project mode also tracks method organisation in `Project/Sources/folders.json` (the Explorer folder layout). If the deleted method's name is still listed there, the project references a file that no longer exists.

**Fix:** after deleting a method file, grep the whole project for its name (e.g. `grep -rn "m_Quit"`) and remove any remaining reference, including its entry in `folders.json`'s `"methods"` array.

### ❌ Removing shortcut properties

When replacing `"method"` with `"action"`, preserve all existing properties like `"shortcutAccel"`, `"shortcutKey"`, `"title"`, etc. Only the `"method"` key is replaced by `"action"`.

---

## Checklist

- [ ] All menu items in `menus.json` audited for method wrappers
- [ ] Single-command wrapper methods replaced with `"action"` property
- [ ] Wrapper `.4dm` files deleted from `Project/Sources/Methods/`
- [ ] Deleted method names no longer appear anywhere in the project, including `folders.json`
- [ ] Remaining `"method"` references point to methods with real logic
- [ ] All other menu item properties preserved (title, shortcuts, etc.)
- [ ] No orphaned method files left behind

---

## References

- Menu properties (action, method, shortcuts): https://developer.4d.com/docs/Menus/properties
- Menu bars: https://developer.4d.com/docs/Menus/bars
