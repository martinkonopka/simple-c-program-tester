#include <stdlib.h>
#include <stdio.h>
#include <malloc.h>

#ifdef __linux__
#include <malloc.h>
#define MSIZE(ptr) malloc_usable_size((void*)ptr)
#elif defined __APPLE__
#include <malloc/malloc.h>
#define MSIZE(ptr) malloc_size(const void *ptr)
#elif defined _WIN32
#include <malloc.h>
#define MSIZE(ptr) _msize(ptr)
#else
#error "Unknown system"
#endif

extern void* __real_malloc(size_t);
extern void* __real_calloc(size_t nitems, size_t size);
extern void* __real_realloc(void*, size_t);
extern void  __real_free(void*);


void write_mem_log(char* operation, char* caller, void* ptr, size_t size) 
{
#ifdef MEMLOGFILE
    static FILE* log = NULL;

    if (log == NULL) 
    {
        log = fopen(MEMLOGFILE, "w"); 
	    fprintf(log, "op,caller,ptr,size\n");
    }

    fprintf(log, "%s,%s,%p,%d\n", operation, caller, ptr, size);
#else 
#error "Memory logging included but MEMLOGFILE constant was no set. Define path to a file for memory logging, either in code or with the compiler flag -DMEMLOGFILE=\"path\\to\\file.csv\". The target directory must already exist."
#endif
}


void* __wrap_malloc(size_t size) 
{
    void* ptr = __real_malloc(size);

    write_mem_log("+", "m", ptr, size);
    
    return ptr;
}


void* __wrap_calloc(size_t nitems, size_t size)
{
    void* ptr = __real_calloc(nitems, size);

    write_mem_log("+", "c", ptr, nitems * size);           

    return ptr;
}


void* __wrap_realloc(void* ptr, size_t size) 
{
    size_t orig_size = MSIZE(ptr);
    write_mem_log("-", "r", ptr, orig_size);

    ptr = __real_realloc(ptr, size);

    write_mem_log("+", "r", ptr, size);           

    return ptr;
}


void __wrap_free(void* ptr) 
{
    size_t size = MSIZE(ptr);

    write_mem_log("-", "f", ptr, size);
    
    __real_free(ptr);
}