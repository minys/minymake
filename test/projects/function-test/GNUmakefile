#
# This is an example of a top level makefile that uses build.mk. Separating
# target specific toolchain and flags could be implemented as below.
#

ARCH ?= $(shell uname -m)

include settings.$(ARCH)

MODULES := module.mk
MODULES += a/module.mk
MODULES += b/module.mk
MODULES += c/module.mk
MODULES += e/module.mk
MODULES += f/module.mk
MODULES += g/module.mk
MODULES += d/module.mk
MODULES += h/module.mk

include build.mk
