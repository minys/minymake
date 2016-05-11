#
# This is an example of a top level makefile that uses build.mk. Separating
# target specific toolchain and flags could be implemented as below.
#

ARCH ?= $(shell uname -m)

include settings.$(ARCH)

MODULES := module.mk
MODULES += a/module.mk
MODULES += a/test.mk
MODULES += b/module.mk
MODULES += c/module.mk
MODULES += d/module.mk
MODULES += e/module.mk
MODULES += e/test.mk

include build.mk
