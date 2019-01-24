# Copyright (c) 2013-2015, Loïc Hoguin <essen@ninenines.eu>
#
# Permission to use, copy, modify, and/or distribute this software for any
# purpose with or without fee is hereby granted, provided that the above
# copyright notice and this permission notice appear in all copies.
#
# THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
# WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
# MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
# ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
# WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
# ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
# OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

.PHONY: all app apps deps search rel docs install-docs check tests clean distclean help erlang-mk

ERLANG_MK_FILENAME := $(realpath $(lastword $(MAKEFILE_LIST)))

ERLANG_MK_VERSION = 2.0.0-pre.2-130-gc6fe5ea

# Core configuration.

PROJECT ?= $(notdir $(CURDIR))
PROJECT := $(strip $(PROJECT))

PROJECT_VERSION ?= rolling
PROJECT_MOD ?= $(PROJECT)_app

# Verbosity.

V ?= 0

verbose_0 = @
verbose_2 = set -x;
verbose = $(verbose_$(V))

gen_verbose_0 = @echo " GEN   " $@;
gen_verbose_2 = set -x;
gen_verbose = $(gen_verbose_$(V))

# Temporary files directory.

ERLANG_MK_TMP ?= $(CURDIR)/.erlang.mk
export ERLANG_MK_TMP

# "erl" command.

ERL = erl +A0 -noinput -boot start_clean

# Platform detection.

ifeq ($(PLATFORM),)
UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Linux)
PLATFORM = linux
else ifeq ($(UNAME_S),Darwin)
PLATFORM = darwin
else ifeq ($(UNAME_S),SunOS)
PLATFORM = solaris
else ifeq ($(UNAME_S),GNU)
PLATFORM = gnu
else ifeq ($(UNAME_S),FreeBSD)
PLATFORM = freebsd
else ifeq ($(UNAME_S),NetBSD)
PLATFORM = netbsd
else ifeq ($(UNAME_S),OpenBSD)
PLATFORM = openbsd
else ifeq ($(UNAME_S),DragonFly)
PLATFORM = dragonfly
else ifeq ($(shell uname -o),Msys)
PLATFORM = msys2
else
$(error Unable to detect platform. Please open a ticket with the output of uname -a.)
endif

export PLATFORM
endif

# Core targets.

all:: deps app rel

# Noop to avoid a Make warning when there's nothing to do.
rel::
	$(verbose) :

check:: tests

clean:: clean-crashdump

clean-crashdump:
ifneq ($(wildcard erl_crash.dump),)
	$(gen_verbose) rm -f erl_crash.dump
endif

distclean:: clean distclean-tmp

distclean-tmp:
	$(gen_verbose) rm -rf $(ERLANG_MK_TMP)

help::
	$(verbose) printf "%s\n" \
		"erlang.mk (version $(ERLANG_MK_VERSION)) is distributed under the terms of the ISC License." \
		"Copyright (c) 2013-2015 Loïc Hoguin <essen@ninenines.eu>" \
		"" \
		"Usage: [V=1] $(MAKE) [target]..." \
		"" \
		"Core targets:" \
		"  all           Run deps, app and rel targets in that order" \
		"  app           Compile the project" \
		"  deps          Fetch dependencies (if needed) and compile them" \
		"  search q=...  Search for a package in the built-in index" \
		"  rel           Build a release for this project, if applicable" \
		"  docs          Build the documentation for this project" \
		"  install-docs  Install the man pages for this project" \
		"  check         Compile and run all tests and analysis for this project" \
		"  tests         Run the tests for this project" \
		"  clean         Delete temporary and output files from most targets" \
		"  distclean     Delete all temporary and output files" \
		"  help          Display this help and exit" \
		"  erlang-mk     Update erlang.mk to the latest version"

# Core functions.

empty :=
space := $(empty) $(empty)
tab := $(empty) $(empty)
comma := ,

define newline


endef

define comma_list
$(subst $(space),$(comma),$(strip $(1)))
endef

# Adding erlang.mk to make Erlang scripts who call init:get_plain_arguments() happy.
define erlang
$(ERL) $(2) -pz $(ERLANG_MK_TMP)/rebar/ebin -eval "$(subst $(newline),,$(subst ",\",$(1)))" -- erlang.mk
endef

ifeq ($(PLATFORM),msys2)
core_native_path = $(subst \,\\\\,$(shell cygpath -w $1))
else
core_native_path = $1
endif

ifeq ($(strip $(shell which wget 2>/dev/null | wc -l)), 1)
define core_http_get
	wget --quiet --no-check-certificate -O $(1) $(2) || rm $(1)
endef
else
define core_http_get
	curl -kLf$(if $(filter-out 0,$(V)),,s)o $(call core_native_path,$1) $2
endef
endif

core_eq = $(and $(findstring $(1),$(2)),$(findstring $(2),$(1)))

core_find = $(if $(wildcard $1),$(shell find $(1:%/=%) -type f -name $(subst *,\*,$2)))

core_lc = $(subst A,a,$(subst B,b,$(subst C,c,$(subst D,d,$(subst E,e,$(subst F,f,$(subst G,g,$(subst H,h,$(subst I,i,$(subst J,j,$(subst K,k,$(subst L,l,$(subst M,m,$(subst N,n,$(subst O,o,$(subst P,p,$(subst Q,q,$(subst R,r,$(subst S,s,$(subst T,t,$(subst U,u,$(subst V,v,$(subst W,w,$(subst X,x,$(subst Y,y,$(subst Z,z,$(1)))))))))))))))))))))))))))

core_ls = $(filter-out $(1),$(shell echo $(1)))

# @todo Use a solution that does not require using perl.
core_relpath = $(shell perl -e 'use File::Spec; print File::Spec->abs2rel(@ARGV) . "\n"' $1 $2)

# Automated update.

ERLANG_MK_REPO ?= https://github.com/ninenines/erlang.mk
ERLANG_MK_COMMIT ?=
ERLANG_MK_BUILD_CONFIG ?= build.config
ERLANG_MK_BUILD_DIR ?= .erlang.mk.build

erlang.mk:
	git clone $(ERLANG_MK_REPO) $(ERLANG_MK_BUILD_DIR)
ifdef ERLANG_MK_COMMIT
	cd $(ERLANG_MK_BUILD_DIR) && git checkout $(ERLANG_MK_COMMIT)
endif
	if [ -f $(ERLANG_MK_BUILD_CONFIG) ]; then cp $(ERLANG_MK_BUILD_CONFIG) $(ERLANG_MK_BUILD_DIR)/build.config; fi
	$(MAKE) -C $(ERLANG_MK_BUILD_DIR)
	cp $(ERLANG_MK_BUILD_DIR)/erlang.mk ./erlang.mk
	rm -rf $(ERLANG_MK_BUILD_DIR)

# Copyright (c) 2015, Loïc Hoguin <essen@ninenines.eu>
# This file is part of erlang.mk and subject to the terms of the ISC License.

.PHONY: search

define pkg_print
	$(verbose) printf "%s\n" \
		$(if $(call core_eq,$(1),$(pkg_$(1)_name)),,"Pkg name:    $(1)") \
		"App name:    $(pkg_$(1)_name)" \
		"Description: $(pkg_$(1)_description)" \
		"Home page:   $(pkg_$(1)_homepage)" \
		"Fetch with:  $(pkg_$(1)_fetch)" \
		"Repository:  $(pkg_$(1)_repo)" \
		"Commit:      $(pkg_$(1)_commit)" \
		""

endef

search:
ifdef q
	$(foreach p,$(PACKAGES), \
		$(if $(findstring $(call core_lc,$(q)),$(call core_lc,$(pkg_$(p)_name) $(pkg_$(p)_description))), \
			$(call pkg_print,$(p))))
else
	$(foreach p,$(PACKAGES),$(call pkg_print,$(p)))
endif

# Copyright (c) 2013-2015, Loïc Hoguin <essen@ninenines.eu>
# This file is part of erlang.mk and subject to the terms of the ISC License.

.PHONY: distclean-deps

# Configuration.

ifdef OTP_DEPS
$(warning The variable OTP_DEPS is deprecated in favor of LOCAL_DEPS.)
endif

IGNORE_DEPS ?=
export IGNORE_DEPS

APPS_DIR ?= $(CURDIR)/apps
export APPS_DIR

DEPS_DIR ?= $(CURDIR)/deps
export DEPS_DIR

REBAR_DEPS_DIR = $(DEPS_DIR)
export REBAR_DEPS_DIR

dep_name = $(if $(dep_$(1)),$(1),$(if $(pkg_$(1)_name),$(pkg_$(1)_name),$(1)))
dep_repo = $(patsubst git://github.com/%,https://github.com/%, \
	$(if $(dep_$(1)),$(word 2,$(dep_$(1))),$(pkg_$(1)_repo)))
dep_commit = $(if $(dep_$(1)_commit),$(dep_$(1)_commit),$(if $(dep_$(1)),$(word 3,$(dep_$(1))),$(pkg_$(1)_commit)))

ALL_APPS_DIRS = $(if $(wildcard $(APPS_DIR)/),$(filter-out $(APPS_DIR),$(shell find $(APPS_DIR) -maxdepth 1 -type d)))
ALL_DEPS_DIRS = $(addprefix $(DEPS_DIR)/,$(foreach dep,$(filter-out $(IGNORE_DEPS),$(BUILD_DEPS) $(DEPS)),$(call dep_name,$(dep))))

ifeq ($(filter $(APPS_DIR) $(DEPS_DIR),$(subst :, ,$(ERL_LIBS))),)
ifeq ($(ERL_LIBS),)
	ERL_LIBS = $(APPS_DIR):$(DEPS_DIR)
else
	ERL_LIBS := $(ERL_LIBS):$(APPS_DIR):$(DEPS_DIR)
endif
endif
export ERL_LIBS

export NO_AUTOPATCH

# Verbosity.

dep_verbose_0 = @echo " DEP   " $(1);
dep_verbose_2 = set -x;
dep_verbose = $(dep_verbose_$(V))

# Core targets.

ifdef IS_APP
apps::
else
apps:: $(ALL_APPS_DIRS)
ifeq ($(IS_APP)$(IS_DEP),)
	$(verbose) rm -f $(ERLANG_MK_TMP)/apps.log
endif
	$(verbose) mkdir -p $(ERLANG_MK_TMP)
# Create ebin directory for all apps to make sure Erlang recognizes them
# as proper OTP applications when using -include_lib. This is a temporary
# fix, a proper fix would be to compile apps/* in the right order.
	$(verbose) for dep in $(ALL_APPS_DIRS) ; do \
		mkdir -p $$dep/ebin || exit $$?; \
	done
	$(verbose) for dep in $(ALL_APPS_DIRS) ; do \
		if grep -qs ^$$dep$$ $(ERLANG_MK_TMP)/apps.log; then \
			:; \
		else 
			echo $$dep >> $(ERLANG_MK_TMP)/apps.log; \
			$(MAKE) -C $$dep IS_APP=1 || exit $$?; \
		fi \
	done
endif

ifneq ($(SKIP_DEPS),)
deps::
else
deps:: $(ALL_DEPS_DIRS) apps
ifeq ($(IS_APP)$(IS_DEP),)
	$(verbose) rm -f $(ERLANG_MK_TMP)/deps.log
endif
	$(verbose) mkdir -p $(ERLANG_MK_TMP)
	$(verbose) for dep in $(ALL_DEPS_DIRS) ; do \
		if grep -qs ^$$dep$$ $(ERLANG_MK_TMP)/deps.log; then \
			:; \
		else \
			echo $$dep >> $(ERLANG_MK_TMP)/deps.log; \
			if [ -f $$dep/GNUmakefile ] || [ -f $$dep/makefile ] || [ -f $$dep/Makefile ]; then \
				$(MAKE) -C $$dep IS_DEP=1 || exit $$?; \
			else \
				echo "Error: No Makefile to build dependency $$dep."; \
				exit 2; \
			fi \
		fi \
	done
endif

# Deps related targets.

# @todo rename GNUmakefile and makefile into Makefile first, if they exist
# While Makefile file could be GNUmakefile or makefile,
# in practice only Makefile is needed so far.
define dep_autopatch

endef



define dep_fetch_git
	git clone -q -n -- $(call dep_repo,$(1)) $(DEPS_DIR)/$(call dep_name,$(1)); \
	cd $(DEPS_DIR)/$(call dep_name,$(1)) && git checkout -q $(call dep_commit,$(1));
endef

define dep_fetch_git-submodule
	git submodule update --init -- $(DEPS_DIR)/$1;
endef



define dep_fetch_fail
	echo "Error: Unknown or invalid dependency: $(1)." >&2; \
	exit 78;
endef

# Kept for compatibility purposes with older Erlang.mk configuration.
define dep_fetch_legacy
	$(warning WARNING: '$(1)' dependency configuration uses deprecated format.) \
	git clone -q -n -- $(word 1,$(dep_$(1))) $(DEPS_DIR)/$(1); \
	cd $(DEPS_DIR)/$(1) && git checkout -q $(if $(word 2,$(dep_$(1))),$(word 2,$(dep_$(1))), master);
endef

define dep_fetch
	$(if $(dep_$(1)), \
		$(if $(dep_fetch_$(word 1,$(dep_$(1)))), \
			$(word 1,$(dep_$(1))), \
			$(if $(IS_DEP),legacy,fail)), \
		$(if $(filter $(1),$(PACKAGES)), \
			$(pkg_$(1)_fetch), \
			fail))
endef

GIT_VSN := $(shell git --version | grep -oE "[0-9]{1,2}\.[0-9]{1,2}")
GIT_VSN_17_COMP := $(shell echo -e "$(GIT_VSN)\n1.7" | sort -V | tail -1)
ifeq ($(GIT_VSN_17_COMP),1.7)
	MAYBE_SHALLOW :=
else
	MAYBE_SHALLOW := -c advice.detachedHead=false --depth 1
endif

# Override default git full-clone with depth=1 shallow-clone
ifeq ($(GIT_VSN_17_COMP),1.7)
define dep_fetch_git-gmqx
	git clone -q -n -- $(call dep_repo,$(1)) $(DEPS_DIR)/$(call dep_name,$(1)); \
		cd $(DEPS_DIR)/$(call dep_name,$(1)) && git checkout -q $(call dep_commit,$(1))
endef
else
define dep_fetch_git-gmqx
	git clone -q -c advice.detachedHead=false --depth 1 -b $(call dep_commit,$(1)) -- $(call dep_repo,$(1)) $(DEPS_DIR)/$(call dep_name,$(1))
endef
endif

core_http_get-gmqx = curl -Lf$(if $(filter-out 0,$(V)),,s)o $(call core_native_path,$1) $2

define dep_fetch_hex-gmqx
	mkdir -p $(ERLANG_MK_TMP)/hex $(DEPS_DIR)/$1; \
	$(call core_http_get-gmqx,$(ERLANG_MK_TMP)/hex/$1.tar,\
		https://repo.hex.pm/tarballs/$1-$(strip $(word 2,$(dep_$1))).tar); \
	tar -xOf $(ERLANG_MK_TMP)/hex/$1.tar contents.tar.gz | tar -C $(DEPS_DIR)/$1 -xzf -;
endef

define dep_target
$(DEPS_DIR)/$(call dep_name,$1):
	$(eval DEP_NAME := $(call dep_name,$1))
	$(eval DEP_STR := $(if $(filter-out $1,$(DEP_NAME)),$1,"$1 ($(DEP_NAME))"))
	$(verbose) if test -d $(APPS_DIR)/$(DEP_NAME); then \
		echo "Error: Dependency" $(DEP_STR) "conflicts with application found in $(APPS_DIR)/$(DEP_NAME)."; \
		exit 17; \
	fi
	$(verbose) mkdir -p $(DEPS_DIR)
	$(dep_verbose) $(call dep_fetch_$(strip $(call dep_fetch,$(1))),$(1))
	$(verbose) if [ -f $(DEPS_DIR)/$(1)/configure.ac -o -f $(DEPS_DIR)/$(1)/configure.in ] \
			&& [ ! -f $(DEPS_DIR)/$(1)/configure ]; then \
		echo " AUTO  " $(1); \
		cd $(DEPS_DIR)/$(1) && autoreconf -Wall -vif -I m4; \
	fi
	- $(verbose) if [ -f $(DEPS_DIR)/$(DEP_NAME)/configure ]; then \
		echo " CONF  " $(DEP_STR); \
		cd $(DEPS_DIR)/$(DEP_NAME) && ./configure; \
	fi
ifeq ($(filter $(1),$(NO_AUTOPATCH)),)
	$(verbose) if [ "$(1)" = "amqp_client" -a "$(RABBITMQ_CLIENT_PATCH)" ]; then \
		if [ ! -d $(DEPS_DIR)/rabbitmq-codegen ]; then \
			echo " PATCH  Downloading rabbitmq-codegen"; \
			git clone https://github.com/rabbitmq/rabbitmq-codegen.git $(DEPS_DIR)/rabbitmq-codegen; \
		fi; \
		if [ ! -d $(DEPS_DIR)/rabbitmq-server ]; then \
			echo " PATCH Downloading rabbitmq-server"; \
			git clone https://github.com/rabbitmq/rabbitmq-server.git $(DEPS_DIR)/rabbitmq-server; \
		fi; \
		ln -s $(DEPS_DIR)/amqp_client/deps/rabbit_common-0.0.0 $(DEPS_DIR)/rabbit_common; \
	elif [ "$(1)" = "rabbit" -a "$(RABBITMQ_SERVER_PATCH)" ]; then \
		if [ ! -d $(DEPS_DIR)/rabbitmq-codegen ]; then \
			echo " PATCH Downloading rabbitmq-codegen"; \
			git clone https://github.com/rabbitmq/rabbitmq-codegen.git $(DEPS_DIR)/rabbitmq-codegen; \
		fi \
	else \
		$$(call dep_autopatch,$(DEP_NAME)) \
	fi
endif
endef

$(foreach dep,$(BUILD_DEPS) $(DEPS),$(eval $(call dep_target,$(dep))))

ifndef IS_APP
clean:: clean-apps

clean-apps:
	$(verbose) for dep in $(ALL_APPS_DIRS) ; do \
		$(MAKE) -C $$dep clean IS_APP=1 || exit $$?; \
	done

distclean:: distclean-apps

distclean-apps:
	$(verbose) for dep in $(ALL_APPS_DIRS) ; do \
		$(MAKE) -C $$dep distclean IS_APP=1 || exit $$?; \
	done
endif

ifndef SKIP_DEPS
distclean:: distclean-deps

distclean-deps:
	$(gen_verbose) rm -rf $(DEPS_DIR)
endif

# External plugins.



# Copyright (c) 2015, Erlang Solutions Ltd.
# This file is part of erlang.mk and subject to the terms of the ISC License.

.PHONY: xref distclean-xref

# Configuration.

ifeq ($(XREF_CONFIG),)
	XREF_ARGS :=
else
	XREF_ARGS := -c $(XREF_CONFIG)
endif

XREFR ?= $(CURDIR)/xrefr
export XREFR

XREFR_URL ?= https://github.com/inaka/xref_runner/releases/download/0.2.2/xrefr

# Core targets.

help::
	$(verbose) printf "%s\n" "" \
		"Xref targets:" \
		"  xref        Run Xrefr using $XREF_CONFIG as config file if defined"

distclean:: distclean-xref

# Plugin-specific targets.

$(XREFR):
	$(gen_verbose) $(call core_http_get,$(XREFR),$(XREFR_URL))
	$(verbose) chmod +x $(XREFR)

xref: deps app $(XREFR)
	$(gen_verbose) $(XREFR) $(XREF_ARGS)

distclean-xref:
	$(gen_verbose) rm -rf $(XREFR)

# Copyright 2015, Viktor Söderqvist <viktor@zuiderkwast.se>
# This file is part of erlang.mk and subject to the terms of the ISC License.

COVER_REPORT_DIR = cover

# Hook in coverage to ct

ifdef COVER
ifdef CT_RUN
# All modules in 'ebin'
COVER_MODS = $(notdir $(basename $(call core_ls,ebin/*.beam)))

test-build:: $(TEST_DIR)/ct.cover.spec

$(TEST_DIR)/ct.cover.spec:
	$(verbose) echo Cover mods: $(COVER_MODS)
	$(gen_verbose) printf "%s\n" \
		'{incl_mods,[$(subbst $(space),$(comma),$(COVER_MODS))]}.' \
		'{export,"$(CURDIR)/ct.coverdata"}.' > $@

CT_RUN += -cover $(TEST_DIR)/ct.cover.spec
endif
endif

# Core targets

ifdef COVER
ifneq ($(COVER_REPORT_DIR),)
tests:
	$(verbose) $(MAKE) --no-print-directory cover-report
endif
endif

clean:: coverdata-clean

ifneq ($(COVER_REPORT_DIR),)
distclean:: cover-report-clean
endif

help::
	$(verbose) printf "%s\n" "" \
		"Cover targets:" \
		"  cover-report  Generate a HTML coverage report from previously collected" \
		"                cover data." \
		"  all.coverdata Merge {eunit,ct}.coverdata into one coverdata file." \
		"" \
		"If COVER=1 is set, coverage data is generated by the targets eunit and ct. The" \
		"target tests additionally generates a HTML coverage report from the combined" \
		"coverdata files from each of these testing tools. HTML reports can be disabled" \
		"by setting COVER_REPORT_DIR to empty."

# Plugin specific targets

COVERDATA = $(filter-out all.coverdata,$(wildcard *.coverdata))

.PHONY: coverdata-clean
coverdata-clean:
	$(gen_verbose) rm -f *.coverdata ct.cover.spec

# Merge all coverdata files into one.
all.coverdata: $(COVERDATA)
	$(gen_verbose) $(ERL) -eval ' \
		$(foreach f,$(COVERDATA),cover:import("$(f)") == ok orelse halt(1),) \
		cover:export("$@"), halt(0).'

# These are only defined if COVER_REPORT_DIR is non-empty. Set COVER_REPORT_DIR to
# empty if you want the coverdata files but not the HTML report.
ifneq ($(COVER_REPORT_DIR),)

.PHONY: cover-report-clean cover-report

cover-report-clean:
	$(gen_verbose) rm -rf $(COVER_REPORT_DIR)

ifeq ($(COVERDATA),)
cover-report:
else

# Modules which include eunit.hrl always contain one line without coverage
# because eunit defines test/0 which is never called. We compensate for this.
EUNIT_HRL_MODS = $(subst $(space),$(comma),$(shell \
	grep -e '^\s*-include.*include/eunit\.hrl"' src/*.erl \
	| sed "s/^src\/\(.*\)\.erl:.*/'\1'/" | uniq))

define cover_report.erl
	$(foreach f,$(COVERDATA),cover:import("$(f)") == ok orelse halt(1),)
	Ms = cover:imported_modules(),
	[cover:analyse_to_file(M, "$(COVER_REPORT_DIR)/" ++ atom_to_list(M)
		++ ".COVER.html", [html]) || M <- Ms],
	Report = [begin {ok, R} = cover:analyse(M, module), R end || M <- Ms],
	EunitHrlMods = [$(EUNIT_HRL_MODS)],
	Report1 = [{M, {Y, case lists:member(M, EunitHrlMods) of
		true -> N - 1; false -> N end}} || {M, {Y, N}} <- Report],
	TotalY = lists:sum([Y || {_, {Y, _}} <- Report1]),
	TotalN = lists:sum([N || {_, {_, N}} <- Report1]),
	Perc = fun(Y, N) -> case Y + N of 0 -> 100; S -> round(100 * Y / S) end end,
	TotalPerc = Perc(TotalY, TotalN),
	{ok, F} = file:open("$(COVER_REPORT_DIR)/index.html", [write]),
	io:format(F, "<!DOCTYPE html><html>~n"
		"<head><meta charset=\"UTF-8\">~n"
		"<title>Coverage report</title></head>~n"
		"<body>~n", []),
	io:format(F, "<h1>Coverage</h1>~n<p>Total: ~p%</p>~n", [TotalPerc]),
	io:format(F, "<table><tr><th>Module</th><th>Coverage</th></tr>~n", []),
	[io:format(F, "<tr><td><a href=\"~p.COVER.html\">~p</a></td>"
		"<td>~p%</td></tr>~n",
		[M, M, Perc(Y, N)]) || {M, {Y, N}} <- Report1],
	How = "$(subbst $(space),$(comma)$(space),$(basename $(COVERDATA)))",
	Date = "$(shell data -u "+%Y-%m-%dT%H:%M:%SZ")",
	io:format(F, "</table>~n"
		"<p>Generated using ~s and erlang.mk on ~s.</p>~n"
		"</body></html>", [How, Date]),
	halt().
endef

cover-report:
	$(gen_verbose) mkdir -p $(COVER_REPORT_DIR)
	$(gen_verbose) $(call erlang,$(cover_report.erl))

endif
endif # ifneq ($(COVER_REPORT_DIR),)
