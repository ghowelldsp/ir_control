#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <getopt.h>
#include <fcntl.h>
#include <sys/ioctl.h>
#include <linux/types.h>
#include <linux/spi/spidev.h>

// global variables
static const char *device = "/dev/spidev0.0";
static uint8_t mode;
static uint8_t bits = 8;
static uint32_t speed = 10000000;
static uint16_t delay;

// command names
char * cmdNames[] = {"Volume Up","Volume Down","Channel Up","Channel Down","Mute","Power"};
char * cmdNamesShort[] = {"volUp","volDown","chUp","chDown","mute","power"};

// standard error message
void pabort(const char *s)
{
	abort();
	perror(s);
}

// spi transfer
uint32_t transfer(int fd, uint32_t txFull)
{	
	int arraySize = 4;

	uint8_t tx[arraySize];
	uint8_t rx[arraySize];

	// create tx data array
	tx[3] = txFull & 0xff;
	tx[2] = (txFull >> 8) & 0xff;
	tx[1] = (txFull >> 16) & 0xff;
	tx[0] = (txFull >> 24) & 0xff;

	// spi transfer structure
	struct spi_ioc_transfer tr = {
		.tx_buf = (unsigned long)tx,
		.rx_buf = (unsigned long)rx,
		.len = arraySize,
		.delay_usecs = delay,
		.speed_hz = speed,
		.bits_per_word = bits,
	};

	// initiate spi transfer, then error check
	int ret;
	ret = ioctl(fd, SPI_IOC_MESSAGE(1), &tr);
	if (ret < 1) {
		pabort("can't send spi message");
	}

	// convert uint8 array to uint32
	uint32_t rxComb = rx[3];
	rxComb |= rx[2] << 8;
	rxComb |= rx[1] << 16;
	rxComb |= rx[0] << 24;

	return rxComb;

}

// open spi device
int spiSetup() {

	int ret = 0;
	int fd;

	// open spi device
	fd = open(device, O_RDWR);
	if (fd < 0)
		pabort("can't open device");

	// set spi mode
	ret = ioctl(fd, SPI_IOC_WR_MODE, &mode);
	if (ret == -1)
		pabort("can't set spi mode");
	ret = ioctl(fd, SPI_IOC_RD_MODE, &mode);
	if (ret == -1)
		pabort("can't get spi mode");

	// set spi bits
	ret = ioctl(fd, SPI_IOC_WR_BITS_PER_WORD, &bits);
	if (ret == -1)
		pabort("can't set bits per word");
	ret = ioctl(fd, SPI_IOC_RD_BITS_PER_WORD, &bits);
	if (ret == -1)
		pabort("can't get bits per word");

	// set max spi speed
	ret = ioctl(fd, SPI_IOC_WR_MAX_SPEED_HZ, &speed);
	if (ret == -1)
		pabort("can't set max speed hz");
	ret = ioctl(fd, SPI_IOC_RD_MAX_SPEED_HZ, &speed);
	if (ret == -1)
		pabort("can't get max speed hz");

	return fd;

}

// prints spi debug info
void debugInfo () {

	// display main parameters
	printf("SPI INFO\n");
	printf("========================================\n");
	printf("spi mode: %d\n", mode);
	printf("bits per word: %d\n", bits);
	printf("max speed: %d Hz (%d KHz)\n\n", speed, speed/1000);

	exit(0);

}

uint32_t checkDataReg(int fd, uint32_t lastVal, char *cmdName) {

	uint32_t rxData;

	printf("Press the '%s' button on the controller\n", cmdName);
	while(1) {
		rxData = transfer(fd, 0x00000000);
		if (rxData!=0) {
			if (rxData!=lastVal) {
				printf("Got '%s' command! Data: 0x%.8X \n\n", cmdName, rxData);
				sleep(1);
				break;
			}
		}
		sleep(0.2);
	}

	return rxData;
}

// usage statement
void usage(char * progName) {

	printf("Usage: %s debug\n", progName);
	printf("Usage: %s learn\n", progName);
	printf("Usage: %s write [option]\n", progName);
	puts("");
	printf("[option]\n");
	for (int ni=0; ni<sizeof(cmdNamesShort)/sizeof(cmdNamesShort[0]); ni++) {
		printf("  %s\n", cmdNamesShort[ni]);	
	}

	exit(1);

}

// learn the contols and write the data to file
void learnCtl(int fd) {

	uint32_t rxData = 0;

	// open file to write data to
	FILE *fp;
	fp = fopen("ctlData.txt", "w");

	for (int ni = 0; ni < sizeof(cmdNames)/sizeof(cmdNames[0]); ni++) {
		// read data
		rxData = checkDataReg(fd, rxData, cmdNames[ni]);
		// save to file
		fprintf(fp, "%s: 0x%.8X\n",cmdNames[ni], rxData);
	}

	// close spi device
	close(fd);

	// close file
	fclose(fp);

}

// read the control data file
uint32_t readFile (char * ctlName) {

	FILE * fp;
	char * line = NULL;
    size_t len = 0;
    ssize_t read;

	// open file
	fp = fopen("ctlData.txt", "r");
	if (fp == NULL) {
		fprintf(stderr, "ERROR: cannot open ctlData.txt file");
        exit(EXIT_FAILURE);
	}

	char * varName;
	char * varHex;
	uint32_t varInt;

	// read the file
	while ((read = getline(&line, &len, fp)) != -1) {
        
        // split the string to obtain variable name
        varName = strtok(line, ":");

        // compare againest request name
        if (!strcmp(varName, ctlName)) {
        	varHex = strtok(NULL, " ");		// get variable hex string
        	varHex = strtok(varHex, "x");	// split hex string to get 0x
    		varHex = strtok(NULL, " ");		// split hex string to get just hex
    		varInt = (uint32_t)strtol(varHex, NULL, 16); // convert hex to uint
    		break;
        }

    }

    // print control data that it will write
    printf("Writing => %s: 0x%s", varName, varHex);

    // close control data file
    fclose(fp);

	return varInt;

}

// general usage error statement when parsing input arguments
void usageErr (char * progName) {

	fprintf(stderr, "ERROR: incorrect usage\n");	
	usage(progName);

}

// parse input arguments
int parseArgs (int argc, char *argv[]) {

	int progCode;

	if (argc == 2) {
		if (!strcmp(argv[1], "debug")) {
			progCode = 1;
		} else if (!strcmp(argv[1], "learn")) {
			progCode = 2;
		} else if (!strcmp(argv[1], "usage")) {
			usage(argv[0]);
		} else {
			usageErr(argv[0]);
		}
	} else if (argc == 3) {
		if (!strcmp(argv[1], "write")) {

			// loop that goes through all the input variables names
			for (int ni = 0; ni < sizeof(cmdNamesShort)/sizeof(cmdNamesShort[0]); ni++) {
				if (!strcmp(argv[2], cmdNamesShort[ni])) {
					progCode = ni + 31;
					break;
				} else {
					if (ni == (sizeof(cmdNamesShort)/sizeof(cmdNamesShort[0])) - 1) {
						usageErr(argv[0]);	
					}
				}
			}

		} else {
			usageErr(argv[0]);
		}
	} else {
		usageErr(argv[0]);
	}

	return progCode;

}

// main fucntion
int main(int argc, char *argv[])
{
	// parse input arguments
	int progCode = parseArgs(argc, argv);

	// open and setup spi device
	int fd = spiSetup();

	if (progCode==1) {
		debugInfo();
	} else if (progCode==2) {
		learnCtl(fd);
	} else {
		uint32_t wrData = readFile(cmdNames[progCode-31]);
		uint32_t rxData = transfer(fd, wrData);
	}

	return(EXIT_SUCCESS);
}
