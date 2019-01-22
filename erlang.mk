

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

distclean: clean distclean-tmp

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


enddef

define comma_list
$(subst $(space),$(comma),$(strip $(1)))
endef



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

help:
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
