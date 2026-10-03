---
description: "XLIFF localisation rules for 4D projects — menus, forms, and method code"
applyTo: "demo/**/*.4dm,demo/**/*.4DForm,demo/**/menus.json,demo/**/*.xlf"
---

# 4D Project XLIFF Localisation — Agent Rules

## 4D Project Structure

A 4D project has the following layout:

```
Project/
  {ProjectName}.4DProject        ← JSON; contains compatibilityVersion
  Sources/
	menus.json                   ← menu bar and menu definitions
	Forms/{FormName}/
	  form.4DForm                ← form definition (JSON)
	  method.4dm                 ← form method
	  ObjectMethods/{name}.4dm   ← object methods
	  Images/                    ← form-local images
	TableForms/{tableNum}/{formName}/
	  form.4DForm
	  ObjectMethods/
	Methods/{name}.4dm           ← project methods
	DatabaseMethods/             ← onStartup.4dm, etc.
	catalog.4DCatalog            ← table/field definitions (XML)
	settings.4DSettings          ← project settings (XML)
Resources/
  {lang}.lproj/                  ← one folder per language (e.g. en.lproj, ja.lproj, fr.lproj)
	{name}{LANG}.xlf             ← XLIFF files (e.g. menuEN.xlf, menuJA.xlf)
  Images/                        ← shared images
```

### Determining the 4D version

Read the `compatibilityVersion` property from `Project/{ProjectName}.4DProject`:

```json
{ "compatibilityVersion": 2101 }
```

Decoding:

| Value  | Version  |
|--------|----------|
| `2000` | 20.0     |
| `2070` | 20 R7    |
| `20A0` | 20 R10   |
| `2101` | 21.1     |

This determines which command names to use (see below).

### `.gitignore` for 4D projects

Always exclude these from version control:

```gitignore
# macOS
.DS_Store

# 4D runtime / user data
Data/
Logs/
userPreferences.*

# 4D derived/cache
Project/DerivedData/

# Documentation (auto-generated)
Documentation/

# Settings (backup settings, user-specific)
Settings/
```

> Ask the user whether `Settings/` should be tracked or excluded — it may contain shared build/backup settings.

---

## XLIFF Localisation Rules

4D supports XLIFF-based localisation. Strings are resolved at runtime by referencing XLIFF translation unit IDs.

### Two mechanisms for XLIFF references

1. **`:xliff:` notation** — Used directly in JSON property values (menus, form object `"text"` properties, tab labels, etc.):
   ```json
   "title": ":xliff:MenuItemDemo"
   ```

2. **`Localized string` command** — Used in 4D method code (`.4dm` files):
   ```4d
   Localized string:C991("AlertVersionTooOld")
   ```

### XLIFF file structure

Use XLIFF 1.2 format. Each `.xlf` file lives inside the appropriate `Resources/{lang}.lproj/` folder:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<xliff xmlns="urn:oasis:names:tc:xliff:document:1.2" version="1.2">
  <file datatype="plaintext" original="{origin path}" source-language="en" target-language="{lang}">
	<body>
	  <trans-unit id="{XLIFF_ID}" resname="{XLIFF_ID}">
		<source>English text</source>
		<target>Translated text</target>
	  </trans-unit>
	</body>
  </file>
</xliff>
```

### Line breaks inside multi-line strings

4D source text (alert messages, multi-line labels, etc.) uses `\r` (carriage return, `Char(13)`) as its internal line-break convention, not `\n`. When a literal string being replaced contains an embedded line break, preserve the exact byte — inspect the original `.4dm`/`.4DForm` bytes (e.g. `xxd` or a hex-aware view) rather than assuming `\n`, and reproduce the same `\r` byte inside the XLIFF `<source>`/`<target>` text. Silently normalising to `\n` will change the rendered text's line breaks at runtime.

### XLIFF file naming convention

File names **must** include a capitalised language code suffix before the extension:

| Purpose             | English file              | Japanese file            |
|---------------------|---------------------------|--------------------------|
| Menus               | `menuEN.xlf`              | `menuJA.xlf`             |
| Form-specific       | `{FormName}EN.xlf`        | `{FormName}JA.xlf`       |
| Method messages      | `messagesEN.xlf`          | `messagesJA.xlf`         |
| Project-wide forms  | `{ProjectShortName}EN.xlf`| `{ProjectShortName}JA.xlf`|

> **Mistake to avoid:** Do not name files without the language code suffix (e.g. `menu.xlf`). Always use the pattern `{name}{LANG}.xlf`.

### When to create XLIFF files

- Always create XLIFF files for **every supported language**, including the source language (e.g. `en.lproj` for English).
- If a `{lang}.lproj/` directory is missing for a language, create it.
- Group related strings into purpose-specific XLIFF files rather than one monolithic file.

---

### XLIFF grouping: object-name-based vs. ID-based syntax

XLIFF files support two resolution mechanisms, and they **must not be mixed within the same `<group>`**:

1. **Object-name-based (automatic form localisation)** — `<trans-unit>` elements are nested inside `<group resname="[ProjectForm]"> → <group resname="{FormName}">`. The `resname` on each `<trans-unit>` matches a form object name. 4D resolves these automatically by form/object path.

2. **ID-based (`:xliff:` references)** — Standalone `<trans-unit>` elements at the `<body>` level (not inside a `[ProjectForm]` group). The `resname` is an arbitrary ID referenced via `:xliff:resname` in JSON or `Localized string:C991("resname")` in code.

```xml
<body>
  <!-- Object-name-based: grouped by form -->
  <group resname="[ProjectForm]">
    <group resname="HDI2">
      <trans-unit id="1" resname="Text1">
        <source>Edit_Address Form (in design)</source>
        <target>…</target>
      </trans-unit>
    </group>
  </group>

  <!-- ID-based: standalone at body level -->
  <trans-unit resname="TabDescription">
    <source>Description</source>
    <target>…</target>
  </trans-unit>
</body>
```

> **Mistake to avoid:** Do not place ID-based entries (e.g. tab label IDs like `TabDescription`) inside an object-name-based `<group resname="{FormName}">`. They will not resolve correctly via `:xliff:` references because 4D treats entries inside form groups as object-name matches, not ID lookups.

---

## 4D Built-in Common Resources

4D ships its own XLIFF files (`commonEN.xlf`, `commonJA.xlf`, etc.) inside the application bundle. These provide translations for standard UI elements. **Do not duplicate these in project-level XLIFF files.**

### Common IDs provided by 4D (non-exhaustive)

| Group | Example IDs |
|-------|-------------|
| Standard Menus | `CommonMenuFile`, `CommonMenuQuit`, `CommonMenuEdit`, `CommonMenuMode` |
| Menu Items | `CommonMenuItemUndo`, `CommonMenuItemCut`, `CommonMenuItemCopy`, `CommonMenuItemPaste`, `CommonMenuItemClear`, `CommonMenuItemSelectAll`, `CommonMenuItemShowClipboard`, `CommonMenuItemQuit`, `CommonMenuItemDesign`, `CommonMenuRedo` |
| Standard Buttons | `CommonOK`, `CommonCancel`, `CommonRetry`, `CommonQuit`, `CommonAdd`, `CommonDelete`, `CommonEdit`, `CommonDone`, `CommonApply`, `CommonCreate`, `CommonRemove`, `CommonOpen`, `CommonClose`, `CommonYes`, `CommonNo`, `CommonDuplicate`, `CommonRename`, `CommonPrint`, `CommonStop`, `CommonRestart` |
| Obsolete Mode Labels | `ObsoleteModeDesign`, `ObsoleteModeUser`, `ObsoleteModeCreatedMenu` |
| Boolean | `CommonTrue`, `CommonFalse` |

These IDs are referenced via `:xliff:CommonMenuFile` in JSON or `Localized string:C991("CommonOK")` in code, and 4D resolves them from its built-in resources at runtime.

> **Mistake to avoid:** Do not create project-level `<trans-unit>` entries for `Common*` IDs. They are already provided by 4D and adding duplicates may cause conflicts or unexpected behaviour.

> **When to use Common IDs:** Prefer built-in Common IDs for standard menu items and button labels (File, Edit, OK, Cancel, etc.) rather than creating project-specific translations. This ensures consistency with the rest of the 4D UI.

---

## What to Localise

### 1. Menus (`Sources/menus.json`)

Any menu item `"title"` that does **not** already use `:xliff:` notation must be converted.

**Before:**
```json
{ "title": "デモ", "method": "00_Start" }
```

**After:**
```json
{ "title": ":xliff:MenuItemDemo", "method": "00_Start" }
```

Items that are separators (`"isSeparator": true`) or already use `:xliff:` (e.g. `":xliff:CommonMenuFile"`) should be left unchanged.

> See [Menu properties](https://developer.4d.com/docs/Menus/properties) for the full specification.

### 2. Form objects (`Forms/{name}/form.4DForm`)

Scan all form JSON files for literal strings in these properties:

- `"text"` — static text, button labels, list box column headers
- `"labels"` — tab control labels (array of strings)
- `"title"` — group box titles, etc.

**Before:**
```json
"header": { "name": "Header3", "text": "値" }
```

**After:**
```json
"header": { "name": "Header3", "text": ":xliff:HDI2_HeaderValue" }
```

**Tab control labels — Before:**
```json
"labels": ["説明", "サンプル"]
```

**After:**
```json
"labels": [":xliff:HDI2_TabDescription", ":xliff:HDI2_TabSample"]
```

> **Note:** 4D also supports automatic form localisation via `resname` matching (where the XLIFF `resname` matches the form object name). Both approaches are valid, but explicit `:xliff:` references are preferred for clarity and maintainability.

### 3. Method code (`*.4dm` files)

Scan all `.4dm` files for string arguments passed to messaging/UI commands:

| Command               | What to localise                    |
|-----------------------|-------------------------------------|
| `ALERT`               | Message text, button label          |
| `CONFIRM`             | Message, OK button, Cancel button   |
| `Request`             | Message, default value, OK, Cancel  |
| `MESSAGE`             | Message text                        |
| `DISPLAY NOTIFICATION`| Title, message                      |
| `LOG EVENT`           | Message text                        |
| `OBJECT SET TITLE`    | Title string (3rd argument)         |

Replace literal strings with `Localized string:C991("XLIFF_ID")`.

**Before:**
```4d
ALERT:C41("Sorry, this example requires a newer version"; "Quit")
```

**After:**
```4d
ALERT:C41(Localized string:C991("AlertVersionTooOld"); Localized string:C991("AlertButtonQuit"))
```

Also scan for `OBJECT SET TITLE` which dynamically sets UI element text at runtime:

**Before:**
```4d
OBJECT SET TITLE:C194(*; "BtnDemo"; "Quit 4D")
```

**After:**
```4d
OBJECT SET TITLE:C194(*; "BtnDemo"; Localized string:C991("BtnQuit4D"))
```

Also scan for any string literal assigned to object properties that become user-visible text:

```4d
$options.title:=Localized string:C991("HDI_Title")
$options.info:=Localized string:C991("HDI_Info")
```

---

## 4D Command Naming (Version-Aware)

Starting with **4D 20 R7** (`compatibilityVersion >= 2070`), many 4D commands were renamed to simplified forms. Always use the version-appropriate command name.

Reference: [Simplified commands for cleaner codebase](https://blog.4d.com/simplified-commands-for-cleaner-codebase/)

| Legacy name (before 20 R7)    | Simplified name (20 R7+)  | Token   |
|-------------------------------|---------------------------|---------|
| `Get localized string`        | `Localized string`        | `:C991` |
| `Count parameters`            | `Count parameters`        | `:C259` |

> **Mistake to avoid:** Do not use `Get localized string` in projects with `compatibilityVersion >= 2070`. Use `Localized string` instead.

The command token (e.g. `:C991`) remains the same regardless of version. However, **token suffixes are optional** — plain command names work correctly and 4D adds tokens automatically on save. Never invent or guess token numbers; an incorrect token silently resolves to the wrong command. If unsure, omit the token entirely.

**Mandatory verification step — no exceptions, even from apparent memory/confidence:** before writing any `:CNNN` or `:KNN:NN` suffix, grep the actual project source files for that exact `CommandName:CNNN` (or `ConstantName:KNN:NN`) string.
- Match found → copy that verified token character-for-character.
- No match found → write the command/constant name with **no** token suffix. Do not substitute a token you "recall" being correct, one seen in another project, or one from general training knowledge — none of these are verified sources, and a confidently recalled wrong token is just as dangerous as a randomly invented one (a real incident: `Size of array:C267` was written from apparent memory without grepping first; `C267` was not that command's token, so 4D would have silently called a different command). Verifying one command's token does not license guessing another command's token in the same file or statement.

---

## XLIFF ID Naming Conventions

Use descriptive, PascalCase or camelCase IDs that indicate purpose and scope:

| Pattern                  | Example                    | Use case                          |
|--------------------------|----------------------------|-----------------------------------|
| `MenuItem{Name}`         | `MenuItemDemo`             | Menu item titles                  |
| `{Form}_{ObjectHint}`    | `HDI2_HeaderValue`         | Form-specific object text         |
| `{Form}_Tab{Name}`       | `HDI2_TabDescription`      | Tab control labels                |
| `Alert{Description}`     | `AlertVersionTooOld`       | Alert/confirm message text        |
| `AlertButton{Name}`      | `AlertButtonQuit`          | Alert/confirm button labels       |
| `{Feature}_{Property}`   | `HDI_Title`                | Dynamic string assignments        |

---

## Checklist

When localising a 4D project:

- [ ] Verify `.gitignore` is properly configured
- [ ] Check `compatibilityVersion` in `.4DProject` to determine command naming
- [ ] Scan `Sources/menus.json` for non-`:xliff:` titles
- [ ] Scan all `form.4DForm` files for literal `"text"`, `"labels"`, `"title"` values
- [ ] Scan all `.4dm` files for ALERT, CONFIRM, Request, MESSAGE, DISPLAY NOTIFICATION, LOG EVENT with literal strings
- [ ] Scan all `.4dm` files for OBJECT SET TITLE with literal string arguments
- [ ] Scan all `.4dm` files for string assignments to user-visible properties
- [ ] Create `Resources/{lang}.lproj/` directories for all target languages
- [ ] Create XLIFF files with `{name}{LANG}.xlf` naming for every language including the source language
- [ ] Use `:xliff:` notation in JSON files, `Localized string:C991()` in `.4dm` files
- [ ] The `source` element in XLIFF should always contain the English text
- [ ] The `target` element contains the translation (identical to source for English files)
