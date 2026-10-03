---
name: localise-4d-project
description: Localise a 4D demo project (project mode) for the target language. Covers XLIFF for form and code strings, computed attributes that follow the UI language (with orderBy), non-blocking startup windows, and headless verification with tool4d. Use for any change to demo/**.
---

# Localise the 4D demo project

Also follow the 4D convention files in `.github/instructions/`:
- `localisation.instructions.md`
- `startup.instructions.md`
- `variable.declarations.instructions.md`
- `method.visibility.instructions.md`
- `listbox.instructions.md`
- `menu.instructions.md`
- `css.instructions.md` and the others

They apply to `demo/**` and take precedence over the generic advice here.

## 0. Survey first, then make a plan (checkpoint)
- List the forms (`Project/Sources/Forms/*/form.4DForm`) and their visible strings: `text`, `windowTitle`, list
  box headers, placeholder text.
- List the user-facing strings in methods and classes: `ALERT`, labels built in code, status text, and stray
  literals in other languages (e.g. French `"aucun"`).
- Check the data model (`Project/Sources/catalog.4DCatalog`) for per-language fields (`nameEN`, `nameFR`, …).
- Check startup: `On Startup` / `On Server Startup` database methods, and any chained `DIALOG` calls.
- **Present the plan and ask:**
  - the scope: UI labels only, or also data or messages?
  - the languages: source plus target, and keep the existing ones?
  - new attributes (e.g. `nameJA`)?
  - should displayed names follow the UI language?
  - track `Settings/` in git?

## 1. Git hygiene
- `.gitignore` already excludes `demo/*/Data/`, `userPreferences.*/`, `Project/DerivedData/` and `Logs/`.
- **Line endings:** 4D files mix CRLF and LF. Preserve each file's line endings and never convert them in bulk.
  When editing a method, match the endings of the surrounding lines.
- **Command tokens:** before writing any `Command:CNNN` / `Constant:KNN:NN` suffix, grep the project for that
  exact token. If it isn't found, write the plain command name without a token (4D tokenises on save).

## 2. XLIFF
- Files: `Resources/<lang>.lproj/<Area><LANG>.xlf`, e.g. `en.lproj/WelcomeEN.xlf` and `ja.lproj/WelcomeJA.xlf`.
  Use XLIFF 1.2 with `source-language="en"` and `target-language="<lang>"`.
- Use ID-based trans-units directly under `<body>`, with a namespaced ID: `<trans-unit id="Welcome_Title" resname="Welcome_Title">`.
  The `en` file has `<target>` = English.
- Forms: put `":xliff:<ID>"` in `text`, `windowTitle` and list box header `text`.
- Code: use `Localized string("<ID>")`.
- Counts and word order: use a template with a placeholder:
  `Replace string(Localized string("Welcome_SiteCount"); "{n}"; String($count))`, with the entries
  `{n} sites` / `観光名所 {n} 件`.
- XML: escape `&`, `<` and `>`. A literal CR in XML is normalised to LF, so use `&#13;` when CR is required.
- Don't redefine 4D's built-in `Common*` IDs; standard menus already use them.
- If the data changed (e.g. a different country), update the English source text too, and tell the user.

## 3. Names that follow the UI language
Add a computed attribute to the entity class (`Project/Sources/Classes/<Dataclass>Entity.4dm`):

```4d
Class extends Entity

Function get name() : Text
	var $lang : Text
	$lang:=Get database localization(Current localization)
	Case of
		: ($lang="ja")
			return This.nameJA
		Else
			return This.nameEN
	End case

Function orderBy name($event : Object) : Text
	var $lang : Text
	$lang:=Get database localization(Current localization)
	Case of
		: ($lang="ja")
			return "nameJA "+$event.operator
		Else
			return "nameEN "+$event.operator
	End case
```

- Without `orderBy`, sorting on `name` is sequential (`get` runs for every entity). With it, the sort runs on the
  stored attribute.
- If a `name` attribute already exists in the dataclass, ask the user before changing it.
- Replace `nameEN` and similar in list box columns, queries and sorts with `name` where appropriate. Search with
  `query("nameXX = …")` on stored attributes (a computed attribute needs a `query` function to be searchable).

## 4. Non-blocking startup windows
Don't chain blocking `DIALOG` calls from `On Startup`: the first modal window would stay open behind the next one.
The pattern:

```4d
// run (project method), called from On Startup and from a menu
#DECLARE($params : Object)

var $title : Text
$title:=Localized string("Welcome_WindowTitle")

If (Count parameters=0)
	// already open? bring it to the front
	ARRAY LONGINT($windows; 0)
	WINDOW LIST($windows)
	var $i; $window : Integer
	For ($i; 1; Size of array($windows))
		$window:=$windows{$i}
		If (Window process($window)=1) && (Get window title($window)=$title)
			var $l; $t; $r; $b : Integer
			GET WINDOW RECT($l; $t; $r; $b; $window)
			CALL FORM($window; Formula(SET WINDOW RECT($l; $t; $r; $b; $window)))
			return
		End if
	End for
	CALL WORKER(1; Current method name; {})
Else
	SET MENU BAR(1)
	$window:=Open form window("Welcome"; Plain form window; Horizontally centered; Vertically centered)
	SET WINDOW TITLE($title; $window)
	DIALOG("Welcome"; *)
End if
```

The button that moves on to the next form has the **Accept** action. In its object method, `On Clicked` opens the
next form in a new window with `DIALOG(…; *)` and copies the window title.

## 5. Verify headlessly with tool4d (when available)
Run `tools/tool4d.py`. It works on a temporary copy, never on the repository.

```sh
python tools/tool4d.py demo/<Name> --compile                 # syntax check: expect success true, no errors
python tools/tool4d.py demo/<Name> test.4dm [--data]         # run a custom test method
```

The test method writes its results to `File("/PACKAGE/agent-test.txt")` and then calls `QUIT 4D`. Useful tests:
- **XLIFF:** `SET DATABASE LOCALIZATION("ja")`, then `Localized string("<ID>")` for several IDs. Repeat for `en`.
  A language without a `.lproj` folder can't be selected, and the call fails silently.
- **orderBy:** compare the IDs from `ds.City.all().orderBy("name asc")` and from `orderBy("nameJA asc")`, for
  asc and desc, in each language.
  - To prove the function is called, temporarily make it return `"ID desc"` (in the temp copy only).
- **Data import:** with `--data`, or by running the import code on an empty datastore. Check the counts and that
  the new fields are filled.

tool4d is not available in the cloud agent. In that case, say clearly that the 4D code was not compiled. Forms
can't be shown headlessly: ask the user to open the project in 4D and check the window flow, label fit (Japanese
labels can be longer or shorter) and list box columns.

## 6. Commit
Commit each concern separately: XLIFF, attributes, startup UX and data. Use messages that explain the user-visible
effect.
