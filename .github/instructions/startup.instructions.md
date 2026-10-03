---
description: "Rules for modernising the startup dialog pattern in 4D HDI example projects, including form methods, object methods, and XLIFF localisation"
applyTo: "demo/**/*.4dm,demo/**/*.4DForm,demo/**/*.xlf"
---

# HDI Modernisation Instructions

## Overview

These instructions describe how to modernise the startup pattern (`00_Start` or equivalent) in 4D HDI (How Do I) example projects. The goal is to replace legacy coding patterns with modern, correct alternatives.

---

## Architecture: The Start Method

The start method serves two roles depending on how it is called:

1. **Without parameters** (called by 4D on startup): Detects if the splash window already exists, brings it to front if so, otherwise delegates to the application process via `CALL WORKER`.
2. **With parameters** (called via `CALL WORKER`): Opens the splash form window and displays it modally with `DIALOG(...; *)`.

### Modern Pattern

```4d
#DECLARE($params : Object)

var $splashWindowTitle : Text
$splashWindowTitle:=""

If (Count parameters=0)
	
	ARRAY LONGINT($windows; 0)
	WINDOW LIST($windows)
	
	var $i; $window : Integer
	For ($i; 1; Size of array($windows))
		$window:=$windows{$i}
		If (Window process($window)=1) && (Get window title($window)=$splashWindowTitle)
			var $x; $y; $bottom; $right : Integer
			GET WINDOW RECT($x; $y; $bottom; $right; $window)
			CALL FORM($window; Formula(SET WINDOW RECT($x; $y; $bottom; $right; $window)))
			return 
		End if 
	End for 
	
	CALL WORKER(1; Current method name; {})
	
Else 
	
	SET MENU BAR(1)
	
	var $options : Object
	$options:=New object
	$options.title:=Localized string("HDI_Title")
	$options.blog:="blog.4d.com"
	$options.info:=Localized string("HDI_Info")
	$options.minimumVersion:="XXYY"
	//$options.license:=...  // uncomment if needed
	
	$window:=Open form window("HDI"; Plain form window; Horizontally centered; Vertically centered)
	SET WINDOW TITLE($splashWindowTitle; $window)
	DIALOG("HDI"; $options; *)
	
End if 
```

### Key Principles

| Principle | Explanation |
|-----------|-------------|
| Use `CALL WORKER(1; ...)` | Executes in the application process (worker #1). Replaces `New process` which was used only to create a new event cycle. |
| Use `DIALOG(...; *)` | The asterisk keeps the dialog open without blocking. Eliminates need for `CLOSE WINDOW`. |
| Use `Plain form window` | Never use `Pop up form window` for the splash. Popup windows are for transient menus, not modal dialogs with interactive controls. |
| Install menu bar | `SET MENU BAR(1)` ensures menus remain available after the window is closed. |
| Window reuse | Enumerate existing windows; if the splash is already open, bring it to front via `CALL FORM` + `SET WINDOW RECT` instead of opening a duplicate. |
| Empty window title as identifier | Set the splash window title to an empty string (or a known constant) to identify it later. |
| Pass `{}` or `New object` to `CALL WORKER` | This satisfies the parameter requirement so the `Else` branch executes. Use `{}` (shorthand for `New object`) or `New object`. |

> **Note on `$window` scope:** in the pattern above, `$window` is declared exactly **once**, inside the `If` branch's `For` loop, and then reused in the `Else` branch without a second declaration. This is intentional and correct — 4D `var` declarations are method-scoped, not block-scoped, so declaring `var $window : Integer` again in the `Else` branch (even though it looks like a "different" local from a block-scoped-language habit) produces a **"Redefinition of variable" (550.10)** compiler warning. If your implementation reuses a variable across both branches, declare it once above the `If`/`Else`, not inside each branch.

---

## Architecture: The Demo Button (BtnDemo)

The "Demo" button on the HDI splash form navigates to the main demo form (typically "HDI2"). Its object method handles the transition.

### Modern Pattern

```4d
//the button already has "accept" standard action
If (FORM Event.code=On Clicked)
	
	If (Form.quit)
		INVOKE ACTION(ak return to design mode)
	Else 
		
		var $window : Integer
		$window:=Open form window("HDI2"; Plain form window; Horizontally centered; Vertically centered)
		SET WINDOW TITLE(Get window title(Current form window); $window)
		DIALOG("HDI2"; Form; *)
		
	End if 
	
End if 
```

### Key Principles

| Principle | Explanation |
|-----------|-------------|
| Return to design mode | Use `INVOKE ACTION(ak return to design mode)` instead of `QUIT 4D`. This is graceful and allows the developer to stay in 4D. |
| Pass `Form` to next dialog | Pass the current form data object so state (like `quit`) propagates. |
| Propagate window title | `SET WINDOW TITLE(Get window title(Current form window); $window)` passes the identifier to the next window so the reuse logic still works. |
| Use `DIALOG(...; *)` | Same non-blocking pattern as the splash. No `CLOSE WINDOW` needed. |

---

## Form Definition (form.4DForm)

When an object method file exists at `ObjectMethods/<ObjectName>.4dm`, the form JSON **must** include a `"method"` property referencing it:

```json
"BtnDemo": {
	"type": "button",
	...
	"method": "ObjectMethods/BtnDemo.4dm",
	"events": ["onClick"]
}
```

### Common Mistake

Creating the `.4dm` file without adding `"method": "ObjectMethods/BtnDemo.4dm"` to the object definition in `form.4DForm`. The method will not execute unless referenced in the form JSON.

---

## Form Method (HDI/method.4dm)

The form method handles `On Load` to configure the splash based on `Form` properties. When conditions are not met (version too old, license missing), it sets `Form.quit:=True` and changes the button label.

### Button Label for Quit State

Use `"Close"` as the button label (not `"Quit 4D"`) since the action is now `INVOKE ACTION(ak return to design mode)`.

---

## Anti-Patterns to Avoid

### ❌ `Pop up form window`

```4d
// WRONG - popup windows are for transient menus
$win:=Open form window("HDI"; Pop up form window; ...)
```

**Why:** Pop up form windows dismiss when the user clicks outside. They are not movable. They should not contain controls that respond to key events (like a default button with Return shortcut).

### ❌ `New process` for event cycle

```4d
// WRONG - unnecessary process creation
$ps:=New process(Current method name; 0; Current method name; 0)
```

**Why:** The only reason was to create a new event cycle. `CALL WORKER` + `DIALOG(...; *)` achieves the same without spawning a process.

### ❌ `QUIT 4D` on failure

```4d
// WRONG - abrupt termination
If ($options.quit=True)
	QUIT 4D
End if
```

**Why:** Quitting 4D is hostile in a development context. Use `INVOKE ACTION(ak return to design mode)` to return gracefully to the IDE.

### ❌ Obsolete version checks

```4d
// WRONG - irrelevant in project mode
If (Application version<"1650")
	ALERT(...)
	QUIT 4D
End if
```

**Why:** Any project in `.4DProject` format is already running v17+. The check is dead code.

### ❌ `DIALOG` without asterisk + `CLOSE WINDOW`

```4d
// WRONG - blocking pattern requires explicit window close
DIALOG("HDI"; $options)
CLOSE WINDOW
```

**Why:** `DIALOG(...; *)` is non-blocking and the window is managed by the form lifecycle. No need for `CLOSE WINDOW`.

### ❌ Missing `SET MENU BAR`

**Why:** Without installing a menu bar to the process, menus disappear after the form window closes. Always call `SET MENU BAR(1)` before opening the splash.

### ❌ Missing `"method"` in form.4DForm

**Why:** Object method files are ignored unless explicitly referenced in the form JSON with `"method": "ObjectMethods/<Name>.4dm"`.

### ❌ Unused variables and debug scaffolding

```4d
// WRONG - dead code
C_TEXT($cr)
$cr:=Char(Carriage return)

// WRONG - meaningless in production
If (Shift down)
```

**Why:** Remove all dead code. If debug behaviour is needed, use a proper mechanism (e.g., a settings file or environment variable), not `Shift down`.

---

## Localisation: XLIFF

All user-facing strings must use `Localized string("KeyName")` backed by XLIFF files. Never hardcode UI text in methods.

### XLIFF File Locations

```
Resources/en.lproj/messagesEN.xlf   (source language)
Resources/ja.lproj/messagesJA.xlf   (Japanese)
```

Add additional `<lang>.lproj` folders for other languages as needed.

### Required XLIFF Keys for HDI Splash

| Key | EN | Purpose |
|-----|-----|---------|
| `HDI_Title` | *(project-specific)* | Splash window title text |
| `HDI_Info` | *(project-specific)* | Info label text |
| `BtnClose` | Close | Button label when quit state is true |
| `ErrorViewProMain` | Sorry, this "How do I" (HDI) example demonstrates a 4D View Pro feature. | License error main text |
| `ErrorViewProSub` | You must have a valid 4D View Pro license to continue. | License error sub text |
| `ErrorWriteProMain` | Sorry, this "How do I" (HDI) example demonstrates a 4D Write Pro feature. | License error main text |
| `ErrorWriteProSub` | You must have a valid 4D Write Pro license to continue. | License error sub text |

### XLIFF Entry Format

```xml
<trans-unit id="BtnClose" resname="BtnClose">
  <source>Close</source>
  <target>Close</target>
</trans-unit>
```

For non-source languages, `<target>` contains the translation:

```xml
<trans-unit id="BtnClose" resname="BtnClose">
  <source>Close</source>
  <target>閉じる</target>
</trans-unit>
```

### Anti-Pattern

```4d
// WRONG - hardcoded UI text
OBJECT SET TITLE(*; "BtnDemo"; "Close")
$maintext:="Sorry, this example demonstrates a 4D View Pro feature."

// CORRECT - localised
OBJECT SET TITLE(*; "BtnDemo"; Localized string("BtnClose"))
$maintext:=Localized string("ErrorViewProMain")
```

---

## Variable Declaration Style

| Legacy (avoid) | Modern (use) |
|----------------|--------------|
| `C_LONGINT($1)` | `#DECLARE($params : Object)` |
| `C_LONGINT($x)` | `var $x : Integer` |
| `C_TEXT($t)` | `var $t : Text` |
| `C_OBJECT($o)` | `var $o : Object` |

Use `#DECLARE` for method parameters. Use `var` for local variables. The `C_*` commands are deprecated.

**Array exception:** Typed arrays are still declared with `ARRAY` commands, not `var`:

```4d
ARRAY LONGINT($windows; 0)   // correct for window ID arrays
```

---

## Token Syntax

4D project mode source files use token syntax (e.g., `Count parameters:C259`, `New object:C1471`). Tokens are the `:CNNN` suffix on commands and `:KNN:NN` suffix on constants. 4D adds these automatically when it saves a method file.

### Rules for writing code

- **Token suffixes are optional.** Plain command and constant names (without any `:C` or `:K` suffix) work correctly. 4D resolves the name and adds the token on next save.
- **Never invent or guess token numbers.** An incorrect token causes 4D to resolve to the **wrong command or constant**, producing silent runtime errors that are very difficult to diagnose. For example, writing `INVOKE ACTION:C1354(ak return to design mode:K39:43)` with made-up tokens actually calls a completely different command.
- **If you are unsure of the correct token, omit it entirely.** `INVOKE ACTION(ak return to design mode)` is always safe. `INVOKE ACTION:C9999(...)` is dangerous.
- **Copy tokens only from existing project code** that is known to be correct. Do not look up or calculate token numbers yourself.
- **Mandatory verification step — no exceptions, even from apparent memory/confidence:** before writing any `:CNNN` or `:KNN:NN` suffix, grep the actual project source files for that exact `CommandName:CNNN` (or `ConstantName:KNN:NN`) string.
  - If a match is found, copy that verified token character-for-character.
  - If no match is found, write the command/constant name with **no** token suffix at all. Do not fall back on a token you "recall" being correct, a token seen in a different project, or a token from general training knowledge — none of these are verified sources. Recalled/half-remembered tokens are exactly as dangerous as invented ones, because 4D cannot tell the difference between a wrong guess and a wrong memory.
  - This applies per-command: verifying one command in a file does not license guessing the token for a different command in the same statement or file.
- `var` and `#DECLARE` are language keywords, not commands — they never take tokens.

### Anti-Pattern

```4d
// WRONG — invented token numbers cause 4D to call the wrong command
INVOKE ACTION:C1354(ak return to design mode:K39:43)

// CORRECT — plain names, 4D resolves them
INVOKE ACTION(ak return to design mode)
```

```4d
// WRONG — a real incident: C267 was assumed to be "Size of array" from
// memory/training data, without grepping the project first. C267 is
// actually a different command's token, so this line silently called
// the wrong command instead of "Size of array".
For ($i; 1; Size of array:C267($windows))

// CORRECT — "Size of array" had no verified occurrence anywhere in this
// project's source, so the token is omitted entirely.
For ($i; 1; Size of array($windows))
```

**Why this specific case matters:** the mistake was not a random invented number — the token "looked right" and was written with confidence. That is precisely what makes recalled/half-remembered tokens dangerous: they pass a casual read-through unnoticed. The only reliable defence is the mechanical grep-first rule above, applied every single time, regardless of how certain the token seems.

---

## Checklist

Before considering the modernisation complete:

- [ ] `00_Start.4dm` uses `#DECLARE($params : Object)`
- [ ] No `C_*` variable declarations remain
- [ ] Uses `CALL WORKER(1; Current method name; {})` (not `New process`)
- [ ] Uses `Plain form window` (not `Pop up form window`)
- [ ] Uses `DIALOG(...; *)` (not `DIALOG` + `CLOSE WINDOW`)
- [ ] Calls `SET MENU BAR(1)` before opening the window
- [ ] Window reuse logic present (enumerate windows, bring to front)
- [ ] `BtnDemo` object method file exists
- [ ] `form.4DForm` references the method: `"method": "ObjectMethods/BtnDemo.4dm"`
- [ ] `INVOKE ACTION(ak return to design mode)` replaces `QUIT 4D`
- [ ] Button label says "Close" (not "Quit 4D") in error state
- [ ] No obsolete version checks (v16 check removed)
- [ ] No dead code (`$cr`, `Shift down`, etc.)
- [ ] All token syntax is correct (if tokens are included) or omitted entirely (never guess tokens)
- [ ] All UI strings use `Localized string` with XLIFF keys (no hardcoded text)
- [ ] XLIFF entries exist in all language `.lproj` folders
