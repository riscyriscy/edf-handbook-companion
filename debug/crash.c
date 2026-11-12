#include <stdio.h>
#include <string.h>

struct frame { int id; char name[8]; };

static int parse(struct frame *f, const char *s)
{
	f->id = (int)strlen(s);
	strcpy(f->name, s);	/* overflows for names longer than 7 characters */
	return f->id;
}

int main(int argc, char **argv)
{
	struct frame *f = argc > 1 ? NULL : &(struct frame){0};
	printf("start\n");
	return parse(f, argc > 1 ? argv[1] : "ok");
}
