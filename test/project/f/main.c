#include <stdio.h>
#include <stdlib.h>

#include <shared.h>

int main(void)
{
	test_shared();

#ifdef TEST
    printf("TEST enabled\n");
#endif

	return EXIT_SUCCESS;
}
