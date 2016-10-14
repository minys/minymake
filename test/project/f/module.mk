target := test_libshared
src := main.c
cflags := -I$(TOPDIR)/d
ldflags := -L$(BUILDDIR)/d -lshared
