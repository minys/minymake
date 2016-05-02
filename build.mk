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
.SUFFIXES: .c .cc .h .o

.DELETE_ON_ERROR:

MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += --no-builtin-variables

CC      ?= gcc
CXX     ?= g++
RM      := rm -rf
SED     ?= sed
SHA1SUM ?= sha1sum

CC      := $(shell which $(CC))
CXX     := $(shell which $(CXX))
SED     := $(shell which $(SED))
SHA1SUM := $(shell which $(SHA1SUM))

DEBUG_CFLAGS     ?= -g
DEBUG_CXXFLAGS   ?= -g
GCOV_CFLAGS      ?= -fprofile-arcs -ftest-coverage
GCOV_CXXFLAGS    ?= -fprofile-arcs -ftest-coverage
GCOV_LDFLAGS     ?= -fprofile-arcs
RELEASE_CFLAGS   ?= -O2
RELEASE_CXXFLAGS ?= -O2
STATIC_CFLAGS    ?= -static
STATIC_CXXFLAGS  ?= -static
STATIC_LDFLAGS   ?= -static

BUILD_DIR ?= $(CURDIR)
BUILD_DIR := $(abspath $(BUILD_DIR))
SRC_DIR   := $(CURDIR)

CC_SHA1     := $(shell echo $$($(SHA1SUM) $(CC)) $(CFLAGS) | $(SHA1SUM) | awk '{print $$1}')
CXX_SHA1    := $(shell echo $$($(SHA1SUM) $(CXX)) $(CXXFLAGS) | $(SHA1SUM) | awk '{print $$1}')
LD_CC_SHA1  := $(shell echo $$($(SHA1SUM) $(CC)) $(LDFLAGS) | $(SHA1SUM) | awk '{print $$1}')
LD_CXX_SHA1 := $(shell echo $$($(SHA1SUM) $(CXX)) $(LDFLAGS) | $(SHA1SUM) | awk '{print $$1}')

CHECKSUM_CC     := $(BUILD_DIR)/.c.sha1
CHECKSUM_CXX    := $(BUILD_DIR)/.cxx.sha1
CHECKSUM_LD_CC  := $(BUILD_DIR)/.ld.cc.sha1
CHECKSUM_LD_CXX := $(BUILD_DIR)/.ld.cxx.sha1

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
        @printf ' %-6s \e[0;20m%s\e[0m\n' "$(1)" "$(2)"
        @$(strip $(3))
    endef
    define run_cmd_red
        @printf ' %-6s \e[1;31m%s\e[0m\n' "$(1)" "$(2)"
        @$(strip $(3))
    endef
    define run_cmd_green
        @printf ' %-6s \e[1;32m%s\e[0m\n' "$(1)" "$(2)"
        @$(strip $(3))
    endef
    define run_cmd_silent
        @$(strip $(1))
    endef
endif

define include_module
    target   := # target executable/library (mandatory)
    src      := # target executable/library source (mandatory)
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
    output              := $$(BUILD_DIR)/$$(path)
    target              := $$(abspath $$(output)/$$(target))
    $$(target)_src      := $$(abspath $$(addprefix $$(path)/,$$(src)))
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
        $$(target)_compile_sha1 := $$(CHECKSUM_CC)
        $$(target)_link_sha1    := $$(CHECKSUM_LD_CC)
    else
        $$(target)_ld           := $$(CXX)
        $$(target)_compile_sha1 := $$(CHECKSUM_CXX)
        $$(target)_link_sha1    := $$(CHECKSUM_LD_CXX)
    endif

    ifeq (.so,$$(suffix $$(target)))
        $$(target)_cflags   += -fpic
        $$(target)_cxxflags += -fpic
        $$(target)_ldflags  += -fpic
    endif

    CLEAN   += $$(target)
    CLEAN   += $$($$(target)_obj)
    CLEAN   += $$($$(target)_dep)
    CLEAN   += $$($$(target)_gcno)
    DEPS    += $$($$(target)_dep)
    GCNO    += $$($$(target)_gcno)
    OBJS    += $$($$(target)_obj)
    TARGETS += $$(target)
endef

define clean_rule
clean: $(1)_clean
.PHONY: $(1)_clean
$(1)_clean:
	$$(call run_cmd,RM,$(1),$$(RM) $(1))
endef

define target_rule
$$($(1)_obj): override CFLAGS += $$($(1)_cflags)
$$($(1)_obj): override CXXFLAGS += $$($(1)_cxxflags)
$$($(1)_obj): $$($(1)_module)
$$($(1)_obj): $$($(1)_compile_sha1)
$$($(1)_dep): $$($(1)_module)
$(1): override LD := $$($(1)_ld)
$(1): override LDFLAGS += $$($(1)_ldflags)
$(1): $$($(1)_module)
$(1): $$($(1)_link_sha1)
$(1): $$($(1)_obj)
	$$(call run_cmd_green,LD,$(1),$$($(1)_ld) $$(LDFLAGS) -o $(1) $$($(1)_obj))
endef

define mkdir
    $(call run_cmd_silent,test -d $(1) || mkdir -p $(1))
endef

define depends
    $(call run_cmd,DEP,$(1),$(strip $(2) $(3) -MT "$(patsubst %.d,%.o,$(1))" -M $(4) | $(SED) 's,\(^.*.o:\),$@ \1,' > $(1)))
endef

default: release

$(BUILD_DIR)/%.d: $(SRC_DIR)/%.c
	$(call mkdir,$(dir $@))
	$(call depends,$@,$(CC),$(CFLAGS),$<)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.c $(CHECKSUM_C)
	$(call mkdir,$(dir $@))
	$(call run_cmd,CC,$@,$(CC) $(CFLAGS) -o $@ -c $<)

$(BUILD_DIR)/%.d: $(SRC_DIR)/%.cc
	$(call mkdir,$(dir $@))
	$(call depends,$@,$(CXX),$(CXXFLAGS),$<)

$(BUILD_DIR)/%.o: $(SRC_DIR)/%.cc $(CHECKSUM_CXX)
	$(call mkdir,$(dir $@))
	$(call run_cmd,CXX,$@,$(CXX) $(CXXFLAGS) -o $@ -c $<)

CLEAN   := # List of all generated objects to be removed
DEPS    := # List of all dependency files
GCNO    := # List of all gcov notes
OBJS    := # List of all objects
TARGETS := # List of all executables/libraries

$(foreach module,$(MODULES),$(eval $(call include_module,$(module))))
$(foreach target,$(TARGETS),$(eval $(call target_rule,$(target))))
$(foreach file,$(wildcard $(sort $(CLEAN))),$(eval $(call clean_rule,$(file))))

$(CHECKSUM_CC): FORCE
	$(if $(filter-out $(shell cat $@ 2>/dev/null),$(CC_SHA1)),$(file >$@,$(CC_SHA1)),)

$(CHECKSUM_CXX): FORCE
	$(if $(filter-out $(shell cat $@ 2>/dev/null),$(CXX_SHA1)),$(file >$@,$(CXX_SHA1)),)

$(CHECKSUM_LD_CC): FORCE
	$(if $(filter-out $(shell cat $@ 2>/dev/null),$(LD_CC_SHA1)),$(file >$@,$(LD_CC_SHA1)),)

$(CHECKSUM_LD_CXX): FORCE
	$(if $(filter-out $(shell cat $@ 2>/dev/null),$(LD_CXX_SHA1)),$(file >$@,$(LD_CXX_SHA1)),)

CLEAN += $(CHECKSUM_CC)
CLEAN += $(CHECKSUM_CXX)

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

#.PHONY: mostlyclean
#.PHONY: maintainer-clean
#.PHONY: install
#.PHONY: installcheck
#.PHONY: installdirs
#.PHONY: install-html
#.PHONY: install-dvi
#.PHONY: install-pdf
#.PHONY: install-ps
#.PHONY: install-strip
#.PHONY: uninstall
#.PHONY: TAGS
#.PHONY: info
#.PHONY: dvi
#.PHONY: html
#.PHONY: pdf
#.PHONY: ps
#.PHONY: dist
#.PHONY: check

.PHONY: FORCE
FORCE:

ifneq (clean,$(filter $(MAKECMDGOALS),distclean))
    ifneq (clean,$(filter $(MAKECMDGOALS),clean))
        -include $(DEPS)
    endif
endif
