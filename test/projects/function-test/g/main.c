#include <stdlib.h>
#include <zlib.h>

int
main(int argc, char *argv[])
{
    z_stream defstream;
    defstream.zalloc = Z_NULL;
    defstream.zfree = Z_NULL;
    defstream.opaque = Z_NULL;
    defstream.avail_in = 0u;
    defstream.next_in = 0u;
    defstream.avail_out = 0u;
    defstream.next_out = 0u;
    
    deflateInit(&defstream, Z_BEST_COMPRESSION);

    return EXIT_SUCCESS;
}
