.PHONY: all

PREFIX ?= '/usr/local'
REBAR ?= './rebar3'

all:
	@ echo "Building escript..."
	@ ${REBAR} escriptize
	@ ${REBAR} as dap escriptize

.PHONY: install
install: all
	@ echo "Installing escript..."
	@ mkdir -p '${PREFIX}/bin'
	@ cp _build/default/bin/erlang_ls ${PREFIX}/bin
	@ cp _build/dap/bin/els_dap ${PREFIX}/bin

.PHONY: clean
clean:
	@rm -rf _build

$HOME/.dialyzer_plt:
	dialyzer --build_plt --apps erts kernel stdlib

ci: $HOME/.dialyzer_plt
	${REBAR} do compile, ct, proper --cover --constraint_tries 100, dialyzer, xref, cover, edoc

coveralls:
	${REBAR} coveralls send
