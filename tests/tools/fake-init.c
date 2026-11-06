/* Stands in for systemd in the boot test: reports how / was mounted and which
 * modules are loaded, then powers off. Built static: the test root has no
 * libraries. */
#include <stdio.h>
#include <string.h>
#include <sys/reboot.h>
#include <unistd.h>

static void report(const char *path, const char *tag, int root_only) {
	char line[1024];
	FILE *f = fopen(path, "r");
	if (!f) {
		printf("tundra-test-error cannot open %s\n", path);
		return;
	}
	while (fgets(line, sizeof(line), f)) {
		if (root_only) {
			char dev[256], dir[256];
			if (sscanf(line, "%255s %255s", dev, dir) != 2 || strcmp(dir, "/"))
				continue;
		}
		printf("%s %s", tag, line);
	}
	fclose(f);
}

int main(void) {
	report("/proc/mounts", "tundra-test-root", 1);
	report("/proc/modules", "tundra-test-module", 0);
	printf("tundra-test-pid %d\n", (int)getpid());
	printf("tundra-test-init ok\n");
	fflush(stdout);
	sync();
	reboot(RB_POWER_OFF);
	return 1;
}
