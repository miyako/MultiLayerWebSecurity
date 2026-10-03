PY := .venv/bin/python

.PHONY: all setup inspect extract check figures review pdf demo-zip release-assets clean

all: pdf

setup: $(PY)
$(PY): requirements.txt
	python3 -m venv .venv
	$(PY) -m pip install -q -r requirements.txt
	@touch $(PY)

# Report fonts/colours/positions of the source PDF and suggest technote.json values.
# Writes technote.json only if it has no heading settings yet.
inspect: setup
	$(PY) tools/inspect_pdf.py --write

# One-time disassembly. Never overwrites existing files;
# "$(PY) tools/extract.py --force" starts over (discards edits to source-language files and layouts).
extract: setup
	$(PY) tools/extract.py

# Verify that program code blocks and figure references match the source.
check: setup
	$(PY) tools/build.py --check

# Re-render localised figures into build/figures/.
figures: setup
	$(PY) tools/render_figures.py

# Contact sheets of the localised figures (build/contact-N.png). FIGS="02 04" to select.
review: figures
	$(PY) tools/contact_sheet.py --compare $(FIGS)

# check + figures + two-pass PDF build.
pdf: setup
	$(PY) tools/build.py

# Zip every committed 4D project under demo/ (tracked files only).
demo-zip:
	@mkdir -p build
	@for d in demo/*/; do n=$$(basename "$$d"); \
	  ls "$$d"Project/*.4DProject >/dev/null 2>&1 || continue; \
	  git archive --format=zip --prefix="$$n/" -o "build/$$n.zip" "HEAD:demo/$$n" && echo "wrote: build/$$n.zip"; \
	done

release-assets: pdf demo-zip

clean:
	rm -rf build
