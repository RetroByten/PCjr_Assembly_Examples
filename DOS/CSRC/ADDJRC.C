/* Program to Add a crude JRC Header from a ROM */
#include <stdio.h>
#include <string.h>

unsigned char *rom; /* Buffer to hold the ROM data */
unsigned char *jrc_header; /* Buffer to hold the header */
/* Main Function */
main(argc, argv, envp)
	int argc;
	char **argv;
	char **envp;
	{
	
	/* VARIABLES */
	
	int i;
	char c;
	
	char *file_name;
	FILE *file;
	unsigned int rom_size = 0;
	char *output_file_name;
	FILE *ofile;
		
	int size_of_jrc_str = 0;
	char *jrc_str = "PCjr Cartridge image file"; /* Zero terminated string */
	char *ptr;
	unsigned char terminator1;
	unsigned char terminator2;
	
	unsigned char *str;
	
	unsigned int start_pos = 0;
	int jrc_header_size = 512;
	
	char *creator = "012345678901234567890123456789";
	int size_of_creator = 30; /* Must be 30 bytes */
	
	/* CODE */
	fprintf(stderr,"PCJr Add JRC Header\n");
	if ( argc != 3 ){
		fprintf(stderr,"Arg $1: PCJr ROM file input w/o JRC (ROM.JRB)\n");
		fprintf(stderr,"Arg $2: PCJr ROM file output w/o JRC (ROM.JRC)\n");
		return 1;
	}
	
	file_name = argv[1];
	fprintf(stderr,"PCJr JRC Input ROM: %s\n",file_name);
	output_file_name = argv[2];
	fprintf(stderr,"PCJr Output Binary ROM: %s\n",output_file_name);
	
	/* Open input file */
	file = fopen(file_name,"rb");
	
	/* Determine ROM file size and then reset the file ptr*/
	while(1){
		fgetc(file);
		if(feof(file)){
			break;
		}
		rom_size++;
	}
	rewind(file); 
	
	/* Error out if file is zero */
	if ( rom_size == 0 ){
		fprintf(stderr,"Error reading file, got 0 byte size, exiting.\n");
		fclose(file);
		return 2;
	}
	else {
		fprintf(stderr,"ROM Size: %d bytes\n",rom_size);
	}
		
	/* Allocate memory + 512bytes at the beginning for the header and read the file */
	rom = (unsigned char *)malloc(rom_size);
	for (i = 0; i < rom_size; i++){
		c = getc(file);
		rom[i]=c;
	}
	fclose(file);
	
	/* Checking to see if the file meets the minimum size requirement */
	if ( rom_size < 512 ){
		fprintf(stderr,"ERROR, file size less than 512b, exiting.\n");
		return 3;
	}
		
	/* Determine length of the JRC String and allocate a string to check if the file actually is JRC */
	for (ptr = jrc_str; *ptr != '\0';ptr++){
		size_of_jrc_str++;
	}
	size_of_jrc_str++; /* Add spot for null terminator */
		
	fprintf(stderr,"Size of JRC Str: %d\n",size_of_jrc_str);
	str = (char *)malloc(size_of_jrc_str);
		
	/* Read in the JRC header from the existing ROM */
	for (i = 0; i < size_of_jrc_str-1; i++){
		str[i] = rom[i];
	}
	str[size_of_jrc_str-1] = '\0'; /* Add null terminator */
	terminator1 = rom[size_of_jrc_str-1];
	terminator2 = rom[size_of_jrc_str];

	/* Check to see if file already has JRC header */
	if (strcmp(jrc_str,str) == 0 && terminator1 == 0x0D && terminator2 == 0x0A){
		fprintf(stderr,"ERROR, Found existing JRC header: %s,%02Xh,%02Xh\n",str,terminator1,terminator2);
		free(str);
		free(rom);
		return 4;
	}
	else {
		start_pos=0;
	}
	fprintf(stderr,"Start Position: %d\n",start_pos);
	
	/* Allocate JRC Header buffer */
	jrc_header = (unsigned char *)malloc(jrc_header_size);
	
	/* Write the JRC String to the header buffer */
			/* Write the JRC Header */
	ptr = jrc_str;
	for ( i = 0; i < size_of_jrc_str-1; i++ ){
		jrc_header[i] = *(ptr++);
	}
			
	free(str); /* Free the JRC String memory */
	start_pos = size_of_jrc_str-1;
	fprintf(stderr,"Start Position after JRC String: %d\n",start_pos);
	
		/* Fill in the terminators */
	jrc_header[start_pos++] = 0x0D;
	jrc_header[start_pos++] = 0x0A;
	fprintf(stderr,"Start Position after Terminators: %d\n",start_pos);
		/* Write the JRC Creator */
	ptr = creator;
	for ( i = 0; i < size_of_creator; i++ ){
			jrc_header[start_pos+i] = *(ptr++);
	}
	start_pos+=size_of_creator;
	fprintf(stderr,"Start Position after Creator: %d\n",start_pos);
		/* CR */
	jrc_header[start_pos++] = 0x0D;
	jrc_header[start_pos++] = 0x0A;
	fprintf(stderr,"Start Position after CR: %d\n",start_pos);
		/* 400 Lines for a comment - TODO */
	for ( i = 0; i < 400; i++ ){
			jrc_header[start_pos+i] = 'C';
	}
	start_pos+= 400;
	fprintf(stderr,"Start Position after Comment: %d\n",start_pos);
		/* EOF For DOS TYPE */
	jrc_header[start_pos++] = 0x1A;
	fprintf(stderr,"Start Position after EOF: %d\n",start_pos);
		/* Image Version */
	jrc_header[start_pos++] = 0x00;
	jrc_header[start_pos++] = 0x01;
	fprintf(stderr,"Start Position after image version: %d\n",start_pos);
		/* Segment Address (Little endian */
	jrc_header[start_pos++] = 0x00;
	jrc_header[start_pos++] = 0xe0;
	fprintf(stderr,"Start Position after segment address: %d\n",start_pos);
		/* Address Mask (Little endian */
	jrc_header[start_pos++] = 0x00;
	jrc_header[start_pos++] = 0x04;
	fprintf(stderr,"Start Position after Address mask: %d\n",start_pos);	
	
		/* Reserved */
	for ( i = 0; i < 46; i++ ){
		jrc_header[start_pos+i] = '\0';
	}
	start_pos+= 46;
	fprintf(stderr,"Start Position: %d\n",start_pos);
	
	/* Output ROM file */
	ofile = fopen(output_file_name,"wb"); 
	/* Output JRC Header */
	for (i = 0; i < jrc_header_size; i++ ){
		fprintf(ofile,"%c",jrc_header[i]);
	}
	free(jrc_header);
	
	/* Output ROM Data */
	for (i = 0; i < rom_size; i++){
		fprintf(ofile,"%c",rom[i]);
	}
	close(ofile);
	free(rom); /* Free memory */
	return 0;
}
