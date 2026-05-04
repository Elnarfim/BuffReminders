.PHONY: all lint format check typecheck i18n ascii-clean

all: typecheck lint ascii-clean format

lint:
	luacheck .

# Strip the AI-tell punctuation (em dash, ellipsis, right arrow) from sources.
# Curly quotes are intentionally NOT in the pattern: zhCN/zhTW use them as
# legitimate CJK typography ("..."), and stripping would garble translations.
ascii-clean:
	@find . -type f \( -name '*.lua' -o -name '*.md' -o -name '*.sh' \) \
		-not -path './Libs/*' \
		-not -path './ignored/*' \
		-not -path './Locales/*' \
		-exec sed -i 's/—/-/g; s/…/.../g; s/→/->/g' {} +

format:
	stylua --glob '!ignored/**' --glob '*.lua' .

typecheck:
	lua-language-server --check . --checklevel=Warning

i18n:
	@scripts/check-locales.sh $(ARGS)

check: typecheck lint
	stylua --check --glob '!ignored/**' --glob '*.lua' .
