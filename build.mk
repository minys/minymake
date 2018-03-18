#
# Copyright (c) 2016-2018, Mikael Nyström
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

ifeq (,$(filter target-specific,$(.FEATURES)))
    $(error required GNU Make feature not present: target-specific)
endif
ifeq (,$(filter second-expansion,$(.FEATURES)))
    $(error required GNU Make feature not present: second-expansion)
endif

.DELETE_ON_ERROR:
.SUFFIXES:
.SECONDEXPANSION:

MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables


# -- [ Variables ] -------------------------------------------------------------

CLEAN                 := # generated objects to be removed
DEPS                  := # dependency files
TARGETS               := # all executables/libraries

INSTALL_ALL           := # list of all files to install
INSTALL_DEFAULT       := # binaries/libraries/data files to install
INSTALL_MAN           := # man files to install
UNINSTALL             := # things to uninstall

BUILDDIR              ?= $(abspath $(CURDIR))
SRCDIR                := $(abspath $(CURDIR))

# Installation directories
BINDIR                ?= bin
SBINDIR               ?= sbin
DATADIR               ?= share
DATAROOTDIR           ?= share
INCLUDEDIR            ?= include
LIBDIR                ?= lib
LIBEXECDIR            ?= libexec
MANDIR                ?= $(DATAROOTDIR)/man

# Default permissions when installing files
BIN_PERM              ?= 755
SBIN_PERM             ?= 755
DATA_PERM             ?= 644
LIB_PERM              ?= 644
MAN_PERM              ?= 644

# External tools
AR                    ?= ar
AR                    := $(if $(wildcard $(AR)),$(AR),$(shell which $(AR) 2>/dev/null))
CC                    ?= gcc
CC                    := $(if $(wildcard $(CC)),$(CC),$(shell which $(CC) 2>/dev/null))
CSUM                  ?= sha1sum
CSUM                  := $(if $(wildcard $(CSUM)),$(CSUM),$(shell which $(CSUM) 2>/dev/null))
CXX                   ?= g++
CXX                   := $(if $(wildcard $(CXX)),$(CXX),$(shell which $(CXX) 2>/dev/null))
INSTALL               ?= install
INSTALL               := $(if $(wildcard $(INSTALL)),$(INSTALL),$(shell which $(INSTALL) 2>/dev/null))
PKG_CONFIG            ?= pkg-config
PKG_CONFIG            := $(if $(wildcard $(PKG_CONFIG)),$(PKG_CONFIG),$(shell which $(PKG_CONFIG) 2>/dev/null))

CC_SUFFIX             ?= .c
CXX_SUFFIX            ?= .cc
LIB_PREFIX            ?= lib
LIB_SUFFIX            ?= .so
ARCHIVE_PREFIX        ?= lib
ARCHIVE_SUFFIX        ?= .a

# Default compiler/linker flags
DEBUG_CFLAGS          ?= -g
DEBUG_CXXFLAGS        ?= -g
COV_CFLAGS            ?= -fprofile-arcs -ftest-coverage
COV_CXXFLAGS          ?= -fprofile-arcs -ftest-coverage
COV_LDFLAGS           ?= -fprofile-arcs
RELEASE_CFLAGS        ?= -O2
RELEASE_CXXFLAGS      ?= -O2
STATIC_CFLAGS         ?= -static
STATIC_CXXFLAGS       ?= -static
STATIC_LDFLAGS        ?= -static

IS_GOAL_STATIC        := $(if $(filter static,$(MAKECMDGOALS)),true,false)
IS_GOAL_CLEAN         := $(if $(filter clean,$(MAKECMDGOALS)),true,false)
IS_GOAL_HELP          := $(if $(filter help,$(MAKECMDGOALS)),true,false)

# Input data is hashed and stored between builds in order to detect changes to
# compiler and/or compiler flags passed on the command line. In case a change
# is detected, affected targets will be rebuilt.
#
ifneq ($(CSUM),)
    ifneq ($(CC),)
        CC_CSUM              := $(shell $(CSUM) $(CC))
        COMPILE_CC_CSUM      := $(shell echo $(CC_CSUM) $(CFLAGS) | $(CSUM))
        LINK_CC_CSUM         := $(shell echo $(CC_CSUM) $(LDFLAGS) | $(CSUM))
        COMPILE_CC_CSUM_FILE := $(BUILDDIR)/.compile.cc.checksum
        LINK_CC_CSUM_FILE    := $(BUILDDIR)/.link.cc.checksum
        CLEAN                += $(COMPILE_CC_CSUM_FILE)
        CLEAN                += $(LINK_CC_CSUM_FILE)
    endif
    ifneq ($(CXX),)
        CXX_CSUM              := $(shell $(CSUM) $(CXX))
        COMPILE_CXX_CSUM      := $(shell echo $(CXX_CSUM) $(CXXFLAGS) | $(CSUM))
        LINK_CXX_CSUM         := $(shell echo $(CXX_CSUM) $(LDFLAGS) | $(CSUM))
        COMPILE_CXX_CSUM_FILE := $(BUILDDIR)/.compile.cxx.checksum
        LINK_CXX_CSUM_FILE    := $(BUILDDIR)/.link.cxx.checksum
        CLEAN                 += $(COMPILE_CXX_CSUM_FILE)
        CLEAN                 += $(LINK_CXX_CSUM_FILE)
    endif
else
    $(warning Disabling rebuilding when commandline input changes (no checksum tool available))
endif


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
        @$(strip $(1))
    endef
else
    define run_cmd
        @printf ' %-8s \e[0;20m%s\e[0m\n' "$(1)" "$(subst $(SRCDIR)/,,$(2))"
        @$(strip $(3))
    endef
    define run_cmd_red
        @printf' %-8s \e[1;31m%s\e[0m\n' "$(1)" "$(subst $(SRCDIR)/,,$(2))"
        @$(strip $(3))
    endef
    define run_cmd_green
        @printf ' %-8s \e[1;32m%s\e[0m\n' "$(1)" "$(subst $(SRCDIR)/,,$(2))"
        @$(strip $(3))
    endef
    define run_cmd_silent
        @$(strip $(1))
    endef
endif

define include_module

    # Module keywords
    bin                := # target binary (mandatory xor sbin/lib)
    sbin               := # target system binary (mandatory xor bin/lib)
    cflags             := # target specific CFLAGS (optional)
    cxxflags           := # target specific CXXFLAGS (optional)
    ldflags            := # target specific LDFLAGS (optional)
    data               := # data file(s) (optional)
    lib                := # target library (mandatory xor bin/sbin)
    link_with          := # link target within the project
    link_with_external := # link with external package using pkg-config (optional)
    private_cflags     := # library private cflags
    private_cxxflags   := # library private cxxflags
    private_ldflags    := # library private ldflags
    man                := # target manual file(s) (optional)
    post               := # post build command (optional)
    pre                := # pre build command (optional)
    src                := # target executable/library source (mandatory)
    test               := # target executable/library test (optional)

    # Internal variables related to keywords
    inc_dir     :=
    lib_dir     :=
    target      :=
    target_data :=
    target_man  :=

    include $(1)

    path   := $(dir $(1))
    output := $$(BUILDDIR)/$$(path)

    ifneq (,$$(strip $$(bin)))
        ifeq (,$$(strip $$(src)))
            $$(error 'src' not defined by $(1))
        endif
        target := $$(bin)
    endif

    ifneq (,$$(strip $$(sbin)))
        ifeq (,$$(strip $$(src)))
            $$(error 'src' not defined by $(1))
        endif
        target := $$(sbin)
    endif

    ifneq (,$$(strip $$(lib)))
        ifeq (,$$(strip $$(src)))
            $$(error 'src' not defined by $(1))
        endif
        target  := $$(LIB_PREFIX)$$(lib)$$(LIB_SUFFIX)
        lib_dir := $$(abspath $$(output))
        inc_dir := $$(abspath $$(path))

        ifeq ($$(IS_GOAL_STATIC),true)
            $$(if $$(AR),,$$(error Unable to locate archiver))
            target := $$(patsubst %$$(LIB_SUFFIX),%$$(ARCHIVE_SUFFIX),$$(target))
        endif

        link_with_$$(lib)_dep      := $$(abspath $$(output)/$$(target))
        link_with_$$(lib)_cflags   := -I$$(inc_dir) $$(cflags)
        link_with_$$(lib)_cxxflags := -I$$(inc_dir) $$(cxxflags)
        link_with_$$(lib)_ldflags  := -L$$(lib_dir) -l$$(lib)
        link_with_$$(lib)_module   := $$(abspath $(1))
    endif

    ifneq (,$$(strip $$(test)))
        ifeq (,$$(strip $$(src)))
            $$(error 'src' not defined by $(1))
        endif
        target := $$(test)
    endif

    target               := $$(abspath $$(output)/$$(target))
    $$(target)_src       := $$(abspath $$(addprefix $$(path)/,$$(src)))
    $$(target)_obj       := $$(addsuffix .o,$$(basename $$(src)))
    $$(target)_obj       := $$(abspath $$(addprefix $$(output)/,$$($$(target)_obj)))
    $$(target)_post      := $$(abspath $$(addprefix $$(path)/,$$(post)))
    $$(target)_dep       := $$(patsubst %.o,%.d,$$($$(target)_obj))
    $$(target)_gcno      := $$(patsubst %.o,%.gcno,$$($$(target)_obj))
    $$(target)_gcno      += $$(addsuffix .gcno,$$(target))
    $$(target)_cflags    := $$(cflags)
    $$(target)_cxxflags  := $$(cxxflags)
    $$(target)_ldflags   := $$(ldflags)
    $$(target)_module    := $$(abspath $(1))
    $$(target)_link_with := $$(link_with)

    CLEAN   += $$(target)
    CLEAN   += $$($$(target)_obj)
    CLEAN   += $$($$(target)_dep)
    CLEAN   += $$($$(target)_gcno)
    DEPS    += $$($$(target)_dep)
    TARGETS += $$(target)

    ifeq ($$(CC_SUFFIX),$$(sort $$(suffix $$($$(target)_src))))
        $$(if $$(CC),,$$(error Unable to locate C compiler))
        $$(target)_ld               := $$(CC)
        $$(target)_compile_checksum := $$(COMPILE_CC_CSUM_FILE)
        $$(target)_link_checksum    := $$(LINK_CC_CSUM_FILE)
    else
        $$(if $$(CXX),,$$(error Unable to locate C++ compiler))
        $$(target)_ld               := $$(CXX)
        $$(target)_compile_checksum := $$(COMPILE_CXX_CSUM_FILE)
        $$(target)_link_checksum    := $$(LINK_CXX_CSUM_FILE)
    endif

    ifeq ($$(LIB_SUFFIX),$$(suffix $$(target)))
        $$(target)_cflags   += -fpic
        $$(target)_cxxflags += -fpic
        $$(target)_ldflags  += -fpic -shared
        $$(target)_to       := $$(abspath $(DESTDIR)/$(LIBDIR)/$$(notdir $$(target)))
        $$(target)_perm     := $(LIB_PERM)
        INSTALL_DEFAULT     += $$(target)
        INSTALL_ALL         += $$($$(target)_to)
        CLEAN               += $$(patsubst %$$(LIB_SUFFIX),%$$(ARCHIVE_SUFFIX),$$(target))

        ifneq (,$(filter $$($$(target)_to),$$(INSTALL_ALL)))
            $$(error $$($$(target)_to) declared in $(1) will overwrite a file from another module during install)
        endif
    endif

    ifneq (,$$(strip $$(bin)))
        $$(target)_to   := $$(abspath $(DESTDIR)/$(BINDIR)/$$(notdir $$(target)))
        $$(target)_perm := $(BIN_PERM)
        INSTALL_DEFAULT += $$(target)
        INSTALL_ALL     += $$($$(target)_to)

        ifneq (,$(filter $$($$(target)_to),$$(INSTALL_ALL)))
            $$(error $$($$(target)_to) declared in $(1) will overwrite a file from another module during install)
        endif
    endif

    ifneq (,$$(strip $$(sbin)))
        $$(target)_to   := $$(abspath $(DESTDIR)/$(SBINDIR)/$$(notdir $$(target)))
        $$(target)_perm := $(SBIN_PERM)
        INSTALL_DEFAULT += $$(target)
        INSTALL_ALL     += $$($$(target)_to)

        ifneq (,$(filter $$($$(target)_to),$$(INSTALL_ALL)))
            $$(error $$($$(target)_to) declared in $(1) will overwrite a file from another module during install)
        endif
    endif

    ifneq (,$$(strip $$(link_with_external)))
        $$(if $$(PKG_CONFIG),,$$(error Unable to locate pkg-config))

        ifeq (,$$(shell $$(PKG_CONFIG) --exists $$(link_with_external) && echo exists))
            $$(error $$(link_with_external) used in $(1) does not match any installed modules)
        endif
        
        $$(target)_cflags   += $$(shell $$(PKG_CONFIG) --cflags $$(link_with_external))
        $$(target)_cxxflags += $$($$(target)_cflags)
        $$(target)_ldflags  += $$(shell $$(PKG_CONFIG) --libs $$(link_with_external))
    endif

    ifneq (,$$(strip $$(data)))
        target_data             := $$(abspath $$(addprefix $$(path)/,$$(data)))
        $$(target_data)_to      := $$(abspath $(DESTDIR)/$(DATADIR)/$$(data))
        $$(target_data)_perm    := $(DATA_PERM)
        $$(target_data)_nostrip := 1
        INSTALL_DEFAULT         += $$(target_data)
        INSTALL_ALL             += $$($$(target_data)_to)

        ifneq (,$(filter $$($$(target_data)_to),$$(INSTALL_ALL)))
            $$(error $$($$(target_data)_to) declared in $(1) will overwrite a file from another module during install)
        endif
    endif

    ifneq (,$$(strip $$(man)))
        target_man             := $$(abspath $$(addprefix $$(path)/,$$(man)))
        $$(target_man)_to      := $$(abspath $(DESTDIR)/$(MANDIR)/$$(man))
        $$(target_man)_perm    := $(MAN_PERM)
        $$(target_man)_nostrip := 1
        INSTALL_MAN            += $$(target_man)
        INSTALL_ALL            += $$($$(target_man)_to)

        ifneq (,$(filter $$($$(target_man)_to),$$(INSTALL_ALL)))
            $$(error $$($$(target_man)_to) declared in $(1) will overwrite a file from another module during install) 
        endif
    endif

endef

define clean_rule
clean: $(1)_clean
.PHONY: $(1)_clean
$(1)_clean:
	$$(call run_cmd,RM,$(1),$(RM) $(1))
endef

define install_rule
$(2): $$($(1)_to)
$$($(1)_to): $(1)
ifdef FORCE_INSTALL
$$($(1)_to): FORCE
endif
ifneq (1,$$($(1)_nostrip))
$$($(1)_to): INSTALL_FLAGS += $$(STRIP_FLAG)
endif
$$($(1)_to): $(1)
	$$(call mkdir,$$(dir $$($(1)_to)))
	$$(call run_cmd,INSTALL,$$($(1)_to),$(INSTALL) $$(INSTALL_FLAGS) -m $$($(1)_perm) $(1) $$($(1)_to))
endef

define uninstall_rule
uninstall: $(1)_uninstall
.PHONY: $(1)_uninstall
$(1)_uninstall:
	$$(call run_cmd,RM,$(1),$(RM) $(1))
endef

define target_rule
$$($(1)_obj): override CFLAGS += $$($(1)_cflags)
$$($(1)_obj): private EXTRA_CFLAGS := $$(link_with_$$($(1)_link_with)_cflags)
$$($(1)_obj): override CXXFLAGS += $$($(1)_cxxflags)
$$($(1)_obj): private EXTRA_CXXFLAGS += $$(link_with_$$($(1)_link_with)_cxxflags)
$$($(1)_obj): $$($(1)_module)
$$($(1)_obj): $$($(1)_compile_checksum)
$$($(1)_dep): override CFLAGS += $$($(1)_cflags)
$$($(1)_dep): private EXTRA_CFLAGS := $$(link_with_$$($(1)_link_with)_cflags)
$$($(1)_dep): override CXXFLAGS += $$($(1)_cxxflags)
$$($(1)_dep): private EXTRA_CXXFLAGS := $$(link_with_$$($(1)_link_with)_cxxflags)
$$($(1)_dep): $$($(1)_module)
$$($(1)_dep): $$($(1)_compile_checksum)
$(1): override LD := $$($(1)_ld)
$(1): override LDFLAGS += $$($(1)_ldflags)
$(1): private EXTRA_LDFLAGS := $$(link_with_$$($(1)_link_with)_ldflags)
$(1): $$(link_with_$$($(1)_link_with)_dep)
$(1): $$($(1)_module)
$(1): $$($(1)_link_checksum)
$(1): $$($(1)_obj)
endef

define depends
    $(call run_cmd_silent,$(strip $(2) $(3) $(4) -MT "$(patsubst %.d,%.o,$(1))" -M $(5) | sed 's,\(^.*.o:\),$@ \1,' > $(1)))
endef

define mkdir
    $(call run_cmd_silent,test -d $(1) || mkdir -p $(1))
endef

define verify_input
    $(if $(filter-out $(shell cat $(1) 2>/dev/null),$(2)),$(file >$(1),$(2)),)
endef


# -- [ Rules ] -----------------------------------------------------------------

default: release

ifdef COMPILE_CC_CSUM_FILE
$(COMPILE_CC_CSUM_FILE): CSUM := $(COMPILE_CC_CSUM)
$(LINK_CC_CSUM_FILE): CSUM := $(LINK_CC_CSUM)
endif

ifdef COMPILE_CXX_CSUM_FILE
$(COMPILE_CXX_CSUM_FILE): CSUM := $(COMPILE_CXX_CSUM)
$(LINK_CXX_CSUM_FILE): CSUM := $(LINK_CXX_CSUM)
endif

$(foreach module,$(MODULES),$(eval $(call include_module,$(module))))
$(foreach target,$(TARGETS),$(eval $(call target_rule,$(target))))
$(foreach file,$(INSTALL_DEFAULT),$(eval $(call install_rule,$(file),install)))
$(foreach file,$(INSTALL_MAN),$(eval $(call install_rule,$(file),install-man)))
$(foreach file,$(wildcard $(INSTALL_ALL)),$(eval $(call uninstall_rule,$(file))))
$(foreach file,$(wildcard $(sort $(CLEAN))),$(eval $(call clean_rule,$(file))))

$(BUILDDIR)/%.d: $(SRCDIR)/%$(CC_SUFFIX)
	$(call mkdir,$(dir $@))
	$(call depends,$@,$(CC),$(CFLAGS),$(EXTRA_CFLAGS),$<)

$(BUILDDIR)/%.o: $(SRCDIR)/%$(CC_SUFFIX)
	$(call mkdir,$(dir $@))
	$(call run_cmd,CC,$@,$(CC) $(CFLAGS) $(EXTRA_CFLAGS) -o $@ -c $<)

$(BUILDDIR)/%.d: $(SRCDIR)/%$(CXX_SUFFIX)
	$(call mkdir,$(dir $@))
	$(call depends,$@,$(CXX),$(CXXFLAGS),$(EXTRA_CXXFLAGS),$<)

$(BUILDDIR)/%.o: $(SRCDIR)/%$(CXX_SUFFIX)
	$(call mkdir,$(dir $@))
	$(call run_cmd,CXX,$@,$(CXX) $(CXXFLAGS) $(EXTRA_CXXFLAGS) -o $@ -c $<)

$(BUILDDIR)/%$(LIB_SUFFIX):
	$(call mkdir,$(dir $@))
	$(call run_cmd_green,LD,$@,$(LD) -o $@ $($(@)_obj) $(LDFLAGS))
	$(if $($(@)_post),$(call run_cmd,POST,$@,$($(@)_post) $@),)

$(BUILDDIR)/%$(ARCHIVE_SUFFIX):
	$(call mkdir,$(dir $@))
	$(call run_cmd,AR,$@,$(AR) cr $@ $($(@)_obj))
	$(if $($(@)_post),$(call run_cmd,POST,$@,$($(@)_post) $@),)

$(BUILDDIR)/%:
	$(call mkdir,$(dir $@))
	$(call run_cmd_green,LD,$@,$(LD) -o $@ $($(@)_obj) $(LDFLAGS) $(EXTRA_LDFLAGS))
	$(if $($(@)_post),$(call run_cmd,POST,$@,$($(@)_post) $@),)

$(BUILDDIR)/%.checksum: FORCE
	$(call verify_input,$@,$(CSUM))

.PHONY: all
all: $$(TARGETS)

.PHONY: release
release: CFLAGS += $(RELEASE_CFLAGS)
release: CXXFLAGS += $(RELEASE_CXXFLAGS)
release: all

.PHONY: debug
debug: CFLAGS += $(DEBUG_CFLAGS)
debug: CXXFLAGS += $(DEBUG_CXXFLAGS)
debug: all

.PHONY: coverage
coverage: CFLAGS += $(COV_CFLAGS)
coverage: CXXFLAGS += $(COV_CXXFLAGS)
coverage: LDFLAGS += $(COV_LDFLAGS)
coverage: all

.PHONY: static
static: CFLAGS += $(STATIC_CFLAGS)
static: CXXFLAGS += $(STATIC_CXXFLAGS)
static: LDFLAGS += $(STATIC_LDFLAGS)
static: all

.PHONY: clean
clean:

.PHONY: install
install:

.PHONY: install-man
install-man:

.PHONY: install-strip
install-strip: STRIP_FLAG := -s
install-strip: install

.PHONY: uninstall
uninstall:

.PHONY: FORCE
FORCE:

.PHONY: help
help:
	@echo
	@echo "Build configuration:"
	@echo
	@echo " VERBOSE          : If defined, echo commands as they are executed."
	@echo " BUILDDIR         : If defined, files are generated rooted at BUILDDIR using the same"
	@echo "                    directory structure as they appear in the source tree."
	@echo " DESTDIR          : If defined, files are install at DESTDIR"
	@echo " FORCE_INSTALL    : If defined, 'install' target will install everything even"
	@echo "                    if none or some of the files have not been rebuilt."
	@echo
	@echo "Available targets:"
	@echo
	@echo " release          : Build all using RELEASE_CFLAGS, RELEASE_CXXFLAGS and"
	@echo "                    RELEASE_LDFLAGS."
	@echo " debug            : Build all using DEBUG_CFLAGS, RELEASE_CXXFLAGS and"
	@echo "                    DEBUG_LDFLAGS."
	@echo " coverage         : Build all using COV_CFLAGS, COV_CXXFLAGS and"
	@echo "                    COV_LDFLAGS."
	@echo " static           : Build all using STATIC_CFLAGS, STATIC_CXXFLAGS and"
	@echo "                    STATIC_LDFLAGS."
	@echo " clean            : Remove all generated objects."
	@echo " install          : Build and install to DESTDIR."
	@echo " install-man      : Install manual page(s)."
	@echo " install-strip    : Install and strip binaries."
	@echo " uninstall        : Uninstall project."
	@echo
	@echo "Please see the README for more information."
	@echo

ifeq ($(or $(IS_GOAL_CLEAN),$(IS_GOAL_HELP)),false)
    -include $(DEPS)
endif
