target := test_libshared
src := main.c
cflags := -I$(SRCDIR)/d
ldflags := -L$(BUILDDIR)/d -lshared
