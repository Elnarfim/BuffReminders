.PHONY: all lint format check typecheck compile i18n ascii-clean ascii-check

# Prefer the real Lua 5.1 compiler (enforces the 200-local AND 60-upvalue
# limits WoW hits); fall back to whatever luac is around.
LUAC := $(shell command -v luac5.1 || command -v luac)

all: typecheck lint compile ascii-clean format

lint:
	luacheck .

# Compile-check every source as its own chunk (how WoW loads them) to catch
# Lua 5.1 bytecode limits that luacheck/lua-language-server don't see.
compile:
	@rg --files -g '*.lua' -g '!Libs' -g '!.ignored' | xargs -r $(LUAC) -p

# Strip the AI-tell punctuation (em dash, ellipsis, right arrow) from sources.
ascii-clean:
	@rg -l --glob '*.{lua,md,sh}' -g '!Libs' -g '!Locales' '—|…|→' . \
		| xargs -r sed -i 's/—/-/g; s/…/.../g; s/→/->/g'

# Lua outside Locales is ASCII only: a byte escape such as \194\183 carries a
# non-ASCII character. `-E none` keeps a UTF-8 BOM visible to the match.
ascii-check:
	@! rg -n -E none -g '*.lua' -g '!Libs' -g '!Locales' -g '!.ignored' '[^\x00-\x7F]' .
	@! rg -n --glob '*.{md,sh}' -g '!Libs' '—|…|→' .

format:
	stylua .

typecheck:
	lua-language-server --check . --checklevel=Warning

i18n:
	@scripts/check-locales.sh $(ARGS)

# Changes no file, so CI runs it.
check: typecheck lint compile ascii-check
	stylua --check .
