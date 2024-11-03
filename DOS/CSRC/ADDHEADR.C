/* Program to add a PCJr Cartridge Header to a DOS COM program */
#include <stdio.h>
#include <string.h>

/* DEFINES */
#define COM_OFFSET 0x100 /* Address offset of the first instruction of a COM file */
#define CRC_SIZE 0x02 /* Number of bytes at the end the CRC takes up */
#define ROM_BLOCK_SIZE 0x200 /* 512 Bytes, ROM file size parameter is # of 512 byte chunks */
#define JMP_NEAR_RELATIVE_INSTRUCTION 0xE9
#define JMP_NEAR_RELATIVE_LENGTH 3 /* E9 <low> <high> */
#define CART_SIG_SIZE 0x02
#define CART_SIZE_SIZE 0x01

/* Global VARIABLES */
unsigned char *rom; /* Pointer to buffer to hold the ROM data */
unsigned char *com; /* Will be a pointer offset to the beginning of the COM file */

/* Main Function */
main(argc, argv, envp)
	int argc;
	char **argv;
	char **envp;
	{
	
	/* Local VARIABLES */
	int i;
	int j;
	int k;
	unsigned char c;
	
	char *input_file_name;
	FILE *input_file;
	
	unsigned int com_size; /* Holds the size of the input COM file */
	unsigned int rom_size; /* Holds the size of the output ROM file */
	
	char *output_file_name;
	FILE *output_file;
			
	/* CODE */
	fprintf(stderr,"PCjr Add Cartridge Header\r\n");
	if ( argc != 3 ){
		fprintf(stderr,"Arg $1: PCjr DOS COM file input (ROM.COM)\r\n");
		fprintf(stderr,"Arg $2: PCjr ROM file output (w/o CRC) (ROM.JRA)\n");
		return 1;
	}
	
	input_file_name = argv[1];
	fprintf(stderr,"PCjr Input Binary COM: %s\r\n",input_file_name);
	output_file_name = argv[2];
	fprintf(stderr,"PCjr Output Binary ROM: %s\r\n",output_file_name);
	
	/* Open input file as read/binary */
	input_file = fopen(input_file_name,"rb");
	
	/* Determine the COM file size and then reset the file ptr*/
	com_size = 0;
	while(1){
		fgetc(input_file);
		if(feof(input_file)){
			break;
		}
		com_size++;
	}
	rewind(input_file); /* Reset file pointer back to begining */
	
	/* Error out if file is zero */
	if ( com_size == 0 ){
		fprintf(stderr,"Error reading file, got 0 byte COM size, exiting.\r\n");
		fclose(input_file);
		return 2;
	}
	else {
		fprintf(stderr,"COM Size: %u bytes\r\n",com_size);
	}
	
	/* Calculate output ROM file size, starting with com_size */
	rom_size = com_size;
	
	/* Adding 100h to the ROM size to make room for the COM offset / ROM header */
	rom_size += COM_OFFSET;
	
	/* Add 2 for the CRC */
	rom_size += CRC_SIZE;
	
	fprintf(stderr,"Initial ROM Size: %u bytes\r\n",rom_size);
	
	/* Check if ROM will be an even multiple of 512, if not append remainder */
	fprintf(stderr,"ROM Modulus: %u bytes\r\n", rom_size % ROM_BLOCK_SIZE);
	if ( rom_size % ROM_BLOCK_SIZE != 0 ){
		/* Round up to the next neariest 512 byte offset remainder */
		fprintf(stderr,"Need to round up to next 512K block...\r\n");
		rom_size += ROM_BLOCK_SIZE - (rom_size % ROM_BLOCK_SIZE);
	}
	
	/* Print final size */
	fprintf(stderr,"Output ROM Size: %u bytes\r\n",rom_size);
	
	/* Allocate memory and read the file */
	rom = (unsigned char *)calloc(rom_size,sizeof(unsigned char));
	com = rom + COM_OFFSET; /* Set the COM pointer to the ROM pointer + COM_OFFSET */	
	
	/* Read the COM file data in and place it starting at the com_offset */
	for ( i = 0; i < com_size; i++ ){
		c = getc(input_file);
		com[i] = c;
	}
	/* Close the file */
	fclose(input_file);

	i = 0; /* offset into the ROM[], start at 0 */
	j = 0; /* offset into the COM[], start at 0 */
	

	
	/* Step 1: Setup ROM Signature + Size + Entry */
	rom[i++]=0x55;
	rom[i++]=0xAA;
	rom[i++]=rom_size / ROM_BLOCK_SIZE; /* # of 512 byte chunks */

	/* Skip over DOS RAM entry point at com[0] - 3 bytes*/
	j += JMP_NEAR_RELATIVE_LENGTH; /* Skip past the DOS RAM entry */

	/* Copy the entry point, 3 byte jump */
	rom[i++]=com[j++];
	rom[i++]=com[j++];
	rom[i++]=com[j++];

	/* 
	Each DOS Command is:
		db <size>
		dw <word offset>
		
		ending in a db <size> of 0 to signify the end
	*/
	c = com[j++];
	while ( c != 0 ){
		fprintf(stderr,"Command name length: %u, Command Name:", (unsigned int)c);
		rom[i++] = c; /* Set size of current command */
		for ( k = 0; k < c; k++ ){ /* Copy command name */
			fprintf(stderr,"%c",com[j]);
			rom[i++] = com[j++]; 
		}
		fprintf(stderr,"\r\n");
		/* Copy the command jump instruction  */
		rom[i++]=com[j++];
		rom[i++]=com[j++];
		rom[i++]=com[j++];
		/* Ready the next byte - either a size of a new command or zero */
		c = com[j++];
	}
	rom[i++]=c; /* Set final 0 byte */
	
	/* Output ROM file */
	output_file = fopen(output_file_name,"wb"); 
		
	/* Output ROM Data */
	for (i = 0; i < rom_size; i++){
		fprintf(output_file,"%c",(char)rom[i]);
	}
	close(output_file);
	free(rom); /* Free allocated memory */
	return 0;
}
