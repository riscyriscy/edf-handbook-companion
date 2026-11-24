/* /init of the initramfs: list the DMA channels in sysfs, then wait. */
#include <dirent.h>
#include <stdio.h>
#include <string.h>
#include <sys/mount.h>
#include <unistd.h>

static void show(const char *ch, const char *attr)
{
	char path[320], buf[64] = "";
	FILE *f;
	snprintf(path, sizeof path, "/sys/class/dma/%s/%s", ch, attr);
	f = fopen(path, "r");
	if (f) {
		if (fgets(buf, sizeof buf, f))
			buf[strcspn(buf, "\n")] = 0;
		fclose(f);
	}
	printf(" %s=%s", attr, buf);
}

int main(void)
{
	struct dirent *e;
	DIR *d;
	mount("sysfs", "/sys", "sysfs", 0, NULL);
	sleep(3); /* let dmatest finish */
	printf("init: channels in /sys/class/dma\n");
	d = opendir("/sys/class/dma");
	while (d && (e = readdir(d))) {
		if (e->d_name[0] == '.')
			continue;
		printf("  %s", e->d_name);
		show(e->d_name, "in_use");
		printf("\n");
	}
	fflush(stdout);
	for (;;)
		pause();
}
