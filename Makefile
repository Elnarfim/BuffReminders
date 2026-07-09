.PHONY: all lint format check typecheck compile i18n ascii-clean

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
	@rg -l --glob '*.{lua,md,sh}' -g '!Libs' -g '!Locales' '—|…|→' \
		| xargs -r sed -i 's/—/-/g; s/…/.../g; s/→/->/g'

format:
	stylua .

typecheck:
	lua-language-server --check . --checklevel=Warning

i18n:
	@scripts/check-locales.sh $(ARGS)

check: typecheck lint compile
	stylua --check .
