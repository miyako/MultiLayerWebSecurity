---
description: "Rules for 4D listbox display defaults — disabling truncate-with-ellipsis and enforcing legacy column resizing"
applyTo: "demo/**/*.4DForm"
---

# 4D Listbox Display Defaults — Agent Rules

## Overview

This document specifies two mandatory listbox defaults for all 4D projects:

1. **Disable truncate-with-ellipsis** on all listbox columns (`truncateMode`).
2. **Use legacy column resizing** on all listboxes (`resizingMode`).

---

## Part 1: Truncate with Ellipsis

### The Problem

When `truncateMode` is set to `"withEllipsis"` (the default):

- **On Windows:** The ellipsis is added to the **right side** of the text.
- **On macOS:** The ellipsis is added to the **middle** of the text.

The macOS behaviour is particularly problematic: truncating the middle section of a short word or phrase accomplishes nothing useful. Even on Windows, right-truncation of short values provides no meaningful preview of the full content.

The correct remedy is to **make the column wider** so the full content is visible, rather than hiding parts of the text behind an ellipsis.

---

### The Fix

For every listbox column in the project, set:

```json
"truncateMode": "none"
```

This disables ellipsis truncation. When cell contents exceed the column width, they are simply clipped at the column boundary without any ellipsis indicator.

---

### JSON Grammar Reference

| Property | Data Type | Possible Values | Default |
|----------|-----------|-----------------|---------|
| `truncateMode` | string | `"withEllipsis"`, `"none"` | `"withEllipsis"` |

### Applies To

- List Box Column
- List Box Footer

### Interaction with Other Properties

- When `wordwrap` is enabled on a Text-type column, `truncateMode` has no effect (word-wrapping handles overflow instead).
- For Boolean columns displayed as checkboxes, labels are always clipped regardless of this setting.
- For Boolean columns displayed as pop-up menus, `truncateMode` controls whether labels are truncated with an ellipsis.

---

### Where to Find Listbox Columns

Listbox columns are defined inside listbox objects in form JSON files:

```
Project/Sources/Forms/{FormName}/form.4DForm
```

The structure varies by 4D version:

### Objects as a dictionary (common in modern projects)

```json
{
  "pages": [
    { "objects": {} },
    {
      "objects": {
        "MyListBox": {
          "type": "listbox",
          "columns": [
            {
              "name": "Column1",
              "dataSource": "...",
              "truncateMode": "none"
            }
          ]
        }
      }
    }
  ]
}
```

### Objects as an array (older projects)

```json
{
  "pages": [
    { "objects": [] },
    {
      "objects": [
        {
          "type": "listbox",
          "name": "MyListBox",
          "columns": [
            {
              "name": "Column1",
              "truncateMode": "none"
            }
          ]
        }
      ]
    }
  ]
}
```

In both cases, `columns` is always an **array** of column definition objects.

---

### Audit Procedure

### Step 1: Find all form files

```
Project/Sources/Forms/*/form.4DForm
```

### Step 2: Locate listbox objects

Search each form's pages for objects with `"type": "listbox"`. Remember:
- Page 0 (index 0) contains objects shared across all pages.
- Objects can be stored as a dictionary (keyed by name) or as an array.

### Step 3: Check each column

For every column in every listbox, check whether `truncateMode` is set. If absent or set to `"withEllipsis"`, it needs to be changed.

### Step 4: Set `truncateMode` to `"none"`

Add or update the property on each column object:

```json
"truncateMode": "none"
```

---

### Programmatic Fix (Python)

When processing forms programmatically, handle both object structures:

```python
import json

def fix_truncate_mode(form_path):
    with open(form_path) as f:
        data = json.load(f)

    modified = 0
    for page in data.get('pages', []):
        if not isinstance(page, dict):
            continue
        objects = page.get('objects', {})
        
        # Handle both dict and list structures
        if isinstance(objects, dict):
            items = objects.values()
        elif isinstance(objects, list):
            items = objects
        else:
            continue
        
        for obj in items:
            if not isinstance(obj, dict):
                continue
            if obj.get('type') != 'listbox':
                continue
            columns = obj.get('columns', [])
            for col in columns:
                if isinstance(col, dict):
                    col['truncateMode'] = 'none'
                    modified += 1

    if modified > 0:
        with open(form_path, 'w') as f:
            json.dump(data, f, indent='\t', ensure_ascii=False)
            f.write('\n')
    
    return modified
```

---

## Part 2: Column Resizing Mode

### The Problem

4D listboxes support multiple column resizing modes that control how columns behave when the listbox is resized. The default in modern 4D (when not explicitly set) may be `"rightToLeft"` — a distributed grow mode that proportionally resizes all columns when the listbox width changes.

This automatic redistribution is **not necessarily appropriate** for every listbox or grid UI:

- Column widths are typically **optimised for their content** (e.g., a narrow "ID" column, a wider "Description" column).
- Distributed resizing disrupts these intentional proportions.
- The choice of resize behaviour is **subjective** and should be a deliberate design decision, not a side effect of a default.

### The Fix

For every listbox in the project, set:

```json
"resizingMode": "legacy"
```

This applies **legacy resizing** (also called "last column grows"): only the rightmost column expands or contracts when the listbox is resized. All other columns retain their specified widths.

### JSON Grammar Reference

| Property | Data Type | Possible Values | Recommended |
|----------|-----------|-----------------|-------------|
| `resizingMode` | string | `"rightToLeft"`, `"legacy"` | `"legacy"` |

**Where it is set:** On the **listbox object itself** (not on individual columns).

### Resizing Mode Behaviour

| Value | Name | Behaviour |
|-------|------|-----------|
| `"rightToLeft"` | Proportional | All columns resize proportionally when the listbox width changes. May override manually set column widths. |
| `"legacy"` | Last column grows | Only the last (rightmost) column adjusts its width. Other columns keep their defined `width` values unchanged. |

### Interaction with Column Properties

When using `"legacy"` mode, individual column sizing properties are respected:

| Property | Scope | Purpose |
|----------|-------|---------|
| `width` | Column | Fixed width of the column |
| `minWidth` | Column | Minimum width (user cannot shrink below this) |
| `maxWidth` | Column | Maximum width (user cannot grow beyond this) |
| `resizable` | Column | Whether the user can manually drag-resize this column |

With `"rightToLeft"`, these properties may be overridden by the proportional redistribution algorithm.

---

## Anti-Patterns to Avoid

### ❌ Leaving `truncateMode` unset (relying on default)

```json
{
  "name": "Column1",
  "dataSource": "..."
}
```

**Why:** The default is `"withEllipsis"`, which produces unhelpful mid-text truncation on macOS. Always explicitly set `"truncateMode": "none"`.

### ❌ Setting `truncateMode` only on some columns

**Why:** Be consistent. All columns in all listboxes should have the same policy. Mixing truncation modes within a single listbox is visually inconsistent.

### ❌ Using ellipsis truncation as a substitute for proper column sizing

**Why:** If text doesn't fit, the column is too narrow. Fix the column width (`width`, `minWidth`, `maxWidth` properties) rather than hiding content. Users deserve to see the full data.

### ❌ Forgetting footers

**Why:** `truncateMode` also applies to listbox footers. If footers display text that could be truncated, apply the same rule.

### ❌ Leaving `resizingMode` unset on a listbox

```json
{
  "type": "listbox",
  "name": "MyListBox"
}
```

**Why:** The default may apply proportional resizing, which redistributes column widths when the listbox is resized. This destroys carefully set column proportions. Always explicitly set `"resizingMode": "legacy"`.

### ❌ Using `"rightToLeft"` without deliberate intent

```json
"resizingMode": "rightToLeft"
```

**Why:** Proportional resizing is a subjective UI choice. It may be appropriate for some designs, but it should never be a passive default. If you genuinely want distributed growth, document why.

---

## Relationship to Column Width Properties

When disabling truncation, ensure columns are sized appropriately:

| Property | Purpose |
|----------|---------|
| `width` | Current column width in pixels |
| `minWidth` | Minimum allowed width (prevents shrinking too small) |
| `maxWidth` | Maximum allowed width (prevents excessive growth) |
| `resizable` | Whether the user can manually resize the column |

Setting a reasonable `minWidth` prevents columns from becoming too narrow to display their content — addressing the root cause rather than masking it with truncation.

---

## Runtime Control

The `truncateMode` property can also be controlled at runtime using:

```4d
LISTBOX SET PROPERTY(*; "columnName"; lk truncate mode; lk without ellipsis)
LISTBOX SET PROPERTY(*; "columnName"; lk truncate mode; lk with ellipsis)
```

However, it is preferred to set this statically in the form JSON to ensure consistent behaviour across all environments without requiring runtime code.

---

## Checklist

Before considering the fix complete:

- [ ] All `.4DForm` files scanned for listbox objects
- [ ] Every listbox column in every form has `"truncateMode": "none"`
- [ ] Every listbox object in every form has `"resizingMode": "legacy"`
- [ ] Both page 0 (shared objects) and numbered pages checked
- [ ] Both dict-style and array-style object containers handled
- [ ] Listbox footers checked (if they contain text)
- [ ] No columns left with the default `"withEllipsis"` behaviour
- [ ] No listboxes left with proportional resizing by default
- [ ] Column `minWidth` values reviewed to ensure content visibility

---

## References

- Truncate with ellipsis property: https://developer.4d.com/docs/FormObjects/propertiesDisplay#truncate-with-ellipsis
- Resizing options: https://developer.4d.com/docs/FormObjects/propertiesResizingOptions
- List Box Column properties: https://developer.4d.com/docs/FormObjects/listbox-column
- `LISTBOX SET PROPERTY`: https://developer.4d.com/docs/commands/listbox-set-property
- `LISTBOX Get property`: https://developer.4d.com/docs/commands/listbox-get-property
