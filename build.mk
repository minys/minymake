#
# Copyright (c) 2016, Mikael Nyström
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# * Redistributions of source code must retain the above copyright notice, this
#   list of conditions and the following disclaimer.
#
# * Redistributions in binary form must reproduce the above copyright notice,
#   this list of conditions and the following disclaimer in the documentation
#   and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
# AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
# FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
# OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
# OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#

.SUFFIXES:
.DELETE_ON_ERROR:

MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables


# -- [ Variables ] -------------------------------------------------------------

CLEAN                 := # list of all generated objects to be removed
DEPS                  := # list of all dependency files
GCNO                  := # list of all gcov notes
INSTALL_BIN           := # list of all binaries to install
INSTALL_LIB           := # list of all libraries to install
INSTALL_DATA          := # list of all data files to install
INSTALL_MAN           := # list of all man files to install
OBJS                  := # list of all objects
TARGETS               := # list of all executables/libraries
TESTS                 := # list of all tests

# Standard GNU variables for installation directories
BUILDDIR              ?= $(CURDIR)
BUILDDIR              := $(abspath $(BUILDDIR))
SRCDIR                := $(CURDIR)
BINDIR                ?= bin
SBINDIR               ?= sbin
LIBEXECDIR            ?= libexec
LIBDIR                ?= lib
DATAROOTDIR           ?= share
DATADIR               ?= share
INFODIR               ?= $(DATAROOTDIR)/info
INCLUDEDIR            ?= include
SYSCONFDIR            ?= etc
SHAREDSTATEDIR        ?= com
LOCALSTATEDIR         ?= var
RUNSTATEDIR           ?= run
DOCDIR                ?= doc
HTMLDIR               ?= $(DOCDIR)
DVIDIR                ?= $(DOCDIR)
PDFDIR                ?= $(DOCDIR)
PSDIR                 ?= $(DOCDIR)
MANDIR                ?= $(DATAROOTDIR)/man

# Default permissions when installing files
BIN_PERM              ?= 755
LIB_PERM              ?= 644
DATA_PERM             ?= 644
INFO_PERM             ?= 644
MAN_PERM              ?= 644

CC                    ?= gcc
CC                    := $(shell which $(CC) 2>/dev/null)
CXX                   ?= g++
CXX                   := $(shell which $(CXX) 2>/dev/null)
INSTALL               ?= install
INSTALL               := $(shell which $(INSTALL) 2>/dev/null)

DEBUG_CFLAGS          ?= -g
DEBUG_CXXFLAGS        ?= -g
GCOV_CFLAGS           ?= -fprofile-arcs -ftest-coverage
GCOV_CXXFLAGS         ?= -fprofile-arcs -ftest-coverage
GCOV_LDFLAGS          ?= -fprofile-arcs
RELEASE_CFLAGS        ?= -O2
RELEASE_CXXFLAGS      ?= -O2
STATIC_CFLAGS         ?= -static
STATIC_CXXFLAGS       ?= -static
STATIC_LDFLAGS        ?= -static

# Input data is hashed and stored between builds in order to detect changes to
# compiler and/or compiler flags passed on the command line. In case a change
# is detected, affected targets will be rebuilt.
#
CC_SHA1               := $(shell sha1sum $(CC))
CXX_SHA1              := $(shell sha1sum $(CXX))
COMPILE_CC_SHA1       := $(shell echo $(CC_SHA1) $(CFLAGS) | sha1sum | awk '{print $$1}')
COMPILE_CXX_SHA1      := $(shell echo $(CXX_SHA1) $(CXXFLAGS) | sha1sum | awk '{print $$1}')
LINK_CC_SHA1          := $(shell echo $(CC_SHA1) $(LDFLAGS) | sha1sum | awk '{print $$1}')
LINK_CXX_SHA1         := $(shell echo $(CXX_SHA1) $(LDFLAGS) | sha1sum | awk '{print $$1}')

COMPILE_CC_SHA1_FILE  := $(BUILDDIR)/.compile.cc.sha1
COMPILE_CXX_SHA1_FILE := $(BUILDDIR)/.compile.cxx.sha1
LINK_CC_SHA1_FILE     := $(BUILDDIR)/.link.cc.sha1
LINK_CXX_SHA1_FILE    := $(BUILDDIR)/.link.cxx.sha1

CLEAN                 += $(COMPILE_CC_SHA1_FILE)
CLEAN                 += $(COMPILE_CXX_SHA1_FILE)
CLEAN                 += $(LINK_CC_SHA1_FILE)
CLEAN                 += $(LINK_CXX_SHA1_FILE)


# -- [ Macros ] ----------------------------------------------------------------

ifdef VERBOSE
    define run_cmd
        $(strip $(3))
    endef
    define run_cmd_red
        $(strip $(3))
    endef
    define run_cmd_green
        $(strip $(3))
    endef
    define run_cmd_silent
        $(strip $(1))
    endef
else
    define run_cmd
        @printf ' %-8s \e[0;20m%s\e[0m\n' "$(1)" "$(2)"
        @$(strip $(3))
    endef
    define run_cmd_red
        @printf ' %-8s \e[1;31m%s\e[0m\n' "$(1)" "$(2)"
        @$(strip $(3))
    endef
    define run_cmd_green
        @printf ' %-8s \e[1;32m%s\e[0m\n' "$(1)" "$(2)"
        @$(strip $(3))
    endef
    define run_cmd_silent
        @$(strip $(1))
    endef
endif

# This is the most complex part in this engine, it tries to provide a simple
# and robust interface for the modules. Parsing a module will generate target
# specific data, which later is used to generate rules.
#
define include_module
    data     := # target data
    man      := # target manual
    target   := # target executable/library (mandatory)
    src      := # target executable/library source (mandatory)
    test     := # target executable/library test (optional)
    cflags   := # target specific CFLAGS (optional)
    cxxflags := # target specific CXXFLAGS (optional)
    ldflags  := # target specific LDFLAGS (optional)

    include $(1)

    ifeq (,$$(strip $$(target)))
        $$(error target not defined by $(1))
    endif
    ifeq (,$$(strip $$(src)))
        $$(error src not defined by $(1))
    endif

    path                := $(dir $(1))
    output              := $$(BUILDDIR)/$$(path)
    target              := $$(abspath $$(output)/$$(target))
    $$(target)_src      := $$(abspath $$(addprefix $$(path)/,$$(src)))
    $$(target)_test     := $$(abspath $$(addprefix $$(path)/,$$(test)))
    $$(target)_test     := $$(if $$(wildcard $$($$(target)_test)),$$($$(target)_test),$$(abspath $$(addprefix $$(output)/,$$(test))))
    $$(target)_run_test := $$(if $$(test),$$(abspath $$(output)/.$$(notdir $$(test)).run),)
    $$(target)_obj      := $$(addsuffix .o,$$(basename $$(src)))
    $$(target)_obj      := $$(abspath $$(addprefix $$(output)/,$$($$(target)_obj)))
    $$(target)_dep      := $$(patsubst %.o,%.d,$$($$(target)_obj))
    $$(target)_gcno     := $$(patsubst %.o,%.gcno,$$($$(target)_obj))
    $$(target)_gcno     += $$(addsuffix .gcno,$$(target))
    $$(target)_cflags   := $$(cflags)
    $$(target)_cxxflags := $$(cxxflags)
    $$(target)_ldflags  := $$(ldflags)
    $$(target)_module   := $$(abspath $(1))

    ifeq (.c,$$(sort $$(suffix $$($$(target)_src))))
        $$(target)_ld           := $$(CC)
        $$(target)_compile_sha1 := $$(COMPILE_CC_SHA1_FILE)
        $$(target)_link_sha1    := $$(LINK_CC_SHA1_FILE)
    else
        $$(target)_ld           := $$(CXX)
        $$(target)_compile_sha1 := $$(COMPILE_CXX_SHA1_FILE)
        $$(target)_link_sha1    := $$(LINK_CXX_SHA1_FILE)
    endif

    ifeq (.so,$$(suffix $$(target)))
        $$(target)_cflags   += -fpic
        $$(target)_cxxflags += -fpic
        $$(target)_ldflags  += -fpic
        target_lib          := $$(abspath $(DESTDIR)/$(LIBDIR)/$$(notdir $$(target)))
        $$(target_lib)_to   := $$(target_lib)
        $$(target_lib)_from := $$(target)
        $$(target_lib)_perm := $(LIB_PERM)
        INSTALL_LIB         += $$($$(target_lib)_to)
    else
        target_bin          := $$(abspath $(DESTDIR)/$(BINDIR)/$$(notdir $$(target)))
        $$(target_bin)_to   := $$(target_bin)
        $$(target_bin)_from := $$(target)
        $$(target_bin)_perm := $(BIN_PERM)
        INSTALL_BIN         += $$($$(target_bin)_to)
    endif

    ifneq (,$$(strip $(data)))
        target_data          := $$(abspath $(DESTDIR)/$(DATADIR)/$(data))
        $$(target_data)_to   := $$(target_data)
        $$(target_data)_from := $$(abspath $$(addprefix $$(path)/,$(data)))
        $$(target_data)_perm := $(DATA_PERM)

        ifneq (,$(filter $$($$(target_data)_to),$$(INSTALL_DATA)))
            $$(error $$($$(target_data)_to) declared in $(1) will overwrite data from another module)
        endif

        INSTALL_DATA += $$(target_data)
    endif

    ifneq (,$$(strip $(man)))
        target_man          := $$(abspath $(DESTDIR)/$(MANDIR)/$(man))
        $$(target_man)_to   := $$(target_man)
        $$(target_man)_from := $$(abspath $$(addprefix $$(path)/,$(man)))
        $$(target_man)_perm := $(MAN_PERM)

        ifneq (,$(filter $$($$(target_man)_to),$$(INSTALL_MAN)))
            $$(error $$($$(target_man)_to) declared in $(1) will overwrite manual from another module)
        endif

        INSTALL_MAN += $$(target_man)
    endif

    CLEAN       += $$(target)
    CLEAN       += $$($$(target)_obj)
    CLEAN       += $$($$(target)_dep)
    CLEAN       += $$($$(target)_gcno)
    CLEAN       += $$($$(target)_run_test)
    DEPS        += $$($$(target)_dep)
    GCNO        += $$($$(target)_gcno)
    OBJS        += $$($$(target)_obj)
    TARGETS     += $$(target)
    TESTS       += $$($$(target)_run_test)
endef

define clean_rule
clean: $(1)_clean
.PHONY: $(1)_clean
$(1)_clean:
	$$(call run_cmd,RM,$(1),$(RM) $(1))
endef

define install_rule
install: $$($(1)_to)
$$($(1)_to): $$($(1)_from)
ifdef FORCE_INSTALL
$$($(1)_to): FORCE
endif
$$($(1)_to): $$($(1)_from)
	$$(call mkdir,$$(dir $$($(1)_to)))
	$$(call run_cmd,INSTALL,$(1),$(INSTALL) -m $$($(1)_perm) $$($(1)_from) $$($(1)_to))
endef

define uninstall_rule
uninstall: $(1)_uninstall
$(1)_uninstall:
	$$(call run_cmd,RM,$$($(1)_install),$(RM) $$($(1)_install))
endef

define object_rule
$$($(1)_obj): override CFLAGS += $$($(1)_cflags)
$$($(1)_obj): override CXXFLAGS += $$($(1)_cxxflags)
$$($(1)_obj): $$($(1)_module)
$$($(1)_obj): $$($(1)_compile_sha1)
endef

define target_rule
$$($(1)_dep): $$($(1)_module)
$(1): override LD := $$($(1)_ld)
$(1): override LDFLAGS += $$($(1)_ldflags)
$(1): $$($(1)_module)
$(1): $$($(1)_link_sha1)
$(1): $$($(1)_obj)
	$$(call run_cmd_green,LD,$(1),$$($(1)_ld) $$(LDFLAGS) -o $(1) $$($(1)_obj))
endef

define test_rule
$$($(1)_test): $$(1)
$$($(1)_run_test): $$($(1)_test)
endef

define depends
    $(call run_cmd,DEP,$(1),$(strip $(2) $(3) -MT "$(patsubst %.d,%.o,$(1))" -M $(4) | sed 's,\(^.*.o:\),$@ \1,' > $(1)))
endef

define mkdir
    $(call run_cmd_silent,test -d $(1) || mkdir -p $(1))
endef

define verify_input
    $(if $(filter-out $(shell cat $(1) 2>/dev/null),$(2)),$(file >$(1),$(2)),)
endef


# -- [ Rules ] -----------------------------------------------------------------

default: release

$(foreach module,$(MODULES),$(eval $(call include_module,$(module))))
$(foreach target,$(TARGETS),$(eval $(call target_rule,$(target))))
$(foreach target,$(TARGETS),$(eval $(call object_rule,$(target))))
$(foreach target,$(TARGETS),$(eval $(call test_rule,$(target))))
$(foreach file,$(INSTALL_BIN),$(eval $(call install_rule,$(file))))
$(foreach file,$(INSTALL_LIB),$(eval $(call install_rule,$(file))))
$(foreach file,$(INSTALL_DATA),$(eval $(call install_rule,$(file))))
$(foreach file,$(INSTALL_MAN),$(eval $(call install_rule,$(file))))
$(foreach target,$(TARGETS),$(eval $(call uninstall_rule,$(target))))
$(foreach file,$(wildcard $(sort $(CLEAN))),$(eval $(call clean_rule,$(file))))

.PHONY: all
all: $(TARGETS)

.PHONY: release
release: CFLAGS += $(RELEASE_CFLAGS)
release: CXXFLAGS += $(RELEASE_CXXFLAGS)
release: all

.PHONY: debug
debug: CFLAGS += $(DEBUG_CFLAGS)
debug: CXXFLAGS += $(DEBUG_CXXFLAGS)
debug: all

.PHONY: gcov
gcov: CFLAGS += $(GCOV_CFLAGS)
gcov: CXXFLAGS += $(GCOV_CXXFLAGS)
gcov: LDFLAGS += $(GCOV_LDFLAGS)
gcov: all

.PHONY: static
static: CFLAGS += $(STATIC_CFLAGS)
static: CXXFLAGS += $(STATIC_CXXFLAGS)
static: LDFLAGS += $(STATIC_LDFLAGS)
static: all

.PHONY: clean
clean:

.PHONY: distclean
distclean: clean

.PHONY: mostlyclean
mostlyclean: not-implemented

.PHONY: maintainer-clean
maintainer-clean: not-implemented

.PHONY: install
install:

.PHONY: installcheck
installcheck: not-implemented

.PHONY: install-html
install-html: not-implemented

.PHONY: install-dvi
install-dvi: not-implemented

.PHONY: install-pdf
install-pdf: not-implemented

.PHONY: install-ps
install-ps: not-implemented

.PHONY: install-strip
install-strip: not-implemented

.PHONY: uninstall
uninstall:

.PHONY: TAGS
TAGS: not-implemented

.PHONY: info
info: not-implemented

.PHONY: dvi
dvi: not-implemented

.PHONY: html
html: not-implemented

.PHONY: pdf
pdf: not-implemented

.PHONY: ps
ps: not-implemented

.PHONY: dist
dist: not-implemented

.PHONY: check
check: $(TESTS)

.PHONY: FORCE
FORCE:

$(BUILDDIR)/%.d: $(SRCDIR)/%.c
	$(call mkdir,$(dir $@))
	$(call depends,$@,$(CC),$(CFLAGS),$<)

$(BUILDDIR)/%.o: $(SRCDIR)/%.c
	$(call mkdir,$(dir $@))
	$(call run_cmd,CC,$@,$(CC) $(CFLAGS) -o $@ -c $<)

$(BUILDDIR)/%.d: $(SRCDIR)/%.cc
	$(call mkdir,$(dir $@))
	$(call depends,$@,$(CXX),$(CXXFLAGS),$<)

$(BUILDDIR)/%.o: $(SRCDIR)/%.cc
	$(call mkdir,$(dir $@))
	$(call run_cmd,CXX,$@,$(CXX) $(CXXFLAGS) -o $@ -c $<)

$(BUILDDIR)/%.run:
	$(call run_cmd,TEST,$<,$< && touch $@)

$(COMPILE_CC_SHA1_FILE): SHA1 := $(COMPILE_CC_SHA1)
$(COMPILE_CXX_SHA1_FILE): SHA1 := $(COMPILE_CXX_SHA1)
$(LINK_CC_SHA1_FILE): SHA1 := $(LINK_CC_SHA1)
$(LINK_CXX_SHA1_FILE): SHA1 := $(LINK_CXX_SHA1)

$(BUILDDIR)/%.sha1: FORCE
	$(call verify_input,$@,$(SHA1))

.PHONY: not-implemented
not-implemented:
	$(error this target is not yet implemented)

ifeq (,$(or $(filter clean,$(MAKECMDGOALS)),$(filter distclean,$(MAKECMDGOALS))))
    -include $(DEPS)
endif
