#include "stdio.h"

int main(int argc, char* argv[])
{
	for(int i = 0; i < argc, i++)
		printf("%s%s", i == 1 ? "" : " ", argv[i]);
	printf("\n");

	return 0;
}
