#include <stdio.h>
#include <string.h>

unsigned char *rom;

struct Reg16 {
		unsigned char l;
		unsigned char h;
};

union Reg {
	unsigned int x;
	struct Reg16 LH;
};

unsigned int rol(value,shifts)
	unsigned int value;
	unsigned int shifts;
{
	while (shifts > 0){
		value = (value << 1) | ((value >> 15) & 1);
		shifts--;
	}
	return value;
}
unsigned int ror(value,shifts)
	unsigned int value;
	unsigned int shifts;
{
	while (shifts > 0){
		value = ((value & 1) << 15)  | (value >> 1);
		shifts--;
	}
	return value;
}

unsigned int compute_crc(sub_rom_start_address,sub_rom_size)
	unsigned int sub_rom_start_address;
	unsigned int sub_rom_size;
{
        union Reg a;
        union Reg b;
        union Reg c;
        union Reg d;
        union Reg tmp;

        /* Calculate CRC */
        a.x = 0;
        b.x = 0;
        c.x = sub_rom_size;
        d.x = 0;
		tmp.x = 0;

        b.x = c.x; /* Save the current count into BX */
        d.x = 0xFFFF; /* Init encode register */
        /* CLD ; set dir to increment. string operations increment */
        a.LH.h ^= a.LH.h; /* Init Work Reg High Byte - sets AH to 0 */
        c.LH.l = 0x04; /* Set rotate count */

        while (b.x > 0x02 ){ /* Loop til count = 0000 */
                a.LH.l = rom[sub_rom_start_address + sub_rom_size - b.x]; /* LODSB; Get a byte; */

                d.LH.h ^= a.LH.l; /* XOR DH, AL; Form Aj + Cj + 1 */
                a.LH.l = d.LH.h; /* MOV AL, DH */
                a.x = rol(a.x,c.LH.l);/*a.x = a.x << c.l; // ROL AX, CL; Shift work reg back 4 */
                d.x ^= a.x; /* XOR DX,AX Add result into work reg */
                a.x = rol(a.x,1);/* Shift work reg back 1 */

                /* swap partial sum into result reg; XCHG DH, DL*/
                tmp.LH.l=d.LH.h;
                tmp.LH.h=d.LH.l;
                d.LH.h=tmp.LH.h;
                d.LH.l=tmp.LH.l;

                d.x ^=a.x; /* XOR DX, AX add work reg into results; */
                a.x = ror(a.x,c.LH.l);/* ROR AX,CLShift work reg over 4; */
                a.LH.l &= 0xE0; /* AND AL,0xE0 Clear off efgh */
                d.x ^= a.x; /* XOR DX, AX add abcd into results */
                a.x = ror(a.x,1);/* ROR AX,1 Shift work reg on over (AH = 0 for next pass) */
                d.LH.h ^= a.LH.l; /* XOR DH,ALadd abcd into results low */
                b.x -= 0x01; /* DEC BX Decrement Count */
        }
        d.x |= d.x;
        return d.x;
}

unsigned int check_crc(sub_rom_start_address,sub_rom_size)
	unsigned int sub_rom_start_address;
	unsigned int sub_rom_size;
{
	union Reg a; 
	union Reg b; 
	union Reg c; 
	union Reg d; 
	union Reg tmp;

	/* Calculate CRC */
	a.x = 0;
	b.x = 0;
	c.x = sub_rom_size;
	d.x = 0;
	tmp.x = 0;

	b.x = c.x; /* Save the current count into BX */
	d.x = 0xFFFF; /* Init encode register */
	/* CLD ; set dir to increment. string operations increment */
	a.LH.h ^= a.LH.h; /* Init Work Reg High Byte - sets AH to 0 */
	c.LH.l = 0x04; /* Set rotate count */
	
	while (b.x > 0x00 ){ /* Loop til count = 0000 */
		a.LH.l = rom[sub_rom_start_address + sub_rom_size - b.x]; /* LODSB; Get a byte; */

		d.LH.h ^= a.LH.l; /* XOR DH, AL; Form Aj + Cj + 1 */
		a.LH.l = d.LH.h; /* MOV AL, DH  */
		a.x = rol(a.x,c.LH.l);/*a.x = a.x << c.l; // ROL AX, CL; Shift work reg back 4 */
		d.x ^= a.x; /* XOR DX,AX Add result into work reg */
		a.x = rol(a.x,1);/* Shift work reg back 1 */
	
		/* swap partial sum into result reg; XCHG DH, DL */
		tmp.LH.l=d.LH.h;
		tmp.LH.h=d.LH.l;
		d.LH.h=tmp.LH.h;
		d.LH.l=tmp.LH.l; 

		d.x ^=a.x; /* XOR DX, AX add work reg into results; */
		a.x = ror(a.x,c.LH.l);/* ROR AX,CLShift work reg over 4; */
		a.LH.l &= 0xE0; /* AND AL,0xE0 Clear off efgh */
		d.x ^= a.x; /* XOR DX, AX add abcd into results */
		a.x = ror(a.x,1);/* ROR AX,1 Shift work reg on over (AH = 0 for next pass) */	
		d.LH.h ^= a.LH.l; /* XOR DH,ALadd abcd into results low */
		b.x -= 0x01; /* DEC BX Decrement Count */
	}
	d.x |= d.x;
	return d.x;
}

main(argc, argv, envp)
	int argc;
	char **argv;
	char **envp;
	{
	
	/* VARIABLES */
	char * file_name;
	FILE * file;
	unsigned int rom_size = 0;
	
	unsigned int size_k = 0;
	unsigned int size_half_k = 0;
	
	int i;
	char c;
	int j;
	
	unsigned int num_roms;
	unsigned char *str;
	
	unsigned int start_pos=0;
	char *jrc_str = "PCjr Cartridge image file"; /* Zero terminated string */
		
	char *output_file_name;
	FILE * ofile;
	
	int size_of_jrc_str = 0;
	
	unsigned char terminator1;
	unsigned char terminator2;
	
	unsigned char sig1;
	unsigned char sig2;
	
	unsigned char rom_k_len;
	unsigned char entry1;
	unsigned char entry2;
	unsigned char entry3;
	unsigned char crc1;
	unsigned char crc2;
	unsigned int end_of_rom;
	
	union Reg crc;
	union Reg orig_crc;
	
	
	/* CODE */
	fprintf(stderr,"PCJr Multi-ROM CRC\n");
	if ( argc != 3 ){
		fprintf(stderr,"Arg $1: PCJr ROM file input (ROM.BIN)\n");
		fprintf(stderr,"Arg $2: PCJr ROM file output (ROM.JRB)\n");
		return 1;
	}
	
	file_name = argv[1];
	fprintf(stderr,"PCJr Input ROM: %s\n",file_name);
	
	output_file_name = argv[2];
	fprintf(stderr,"PCJr Output ROM: %s\n",output_file_name);
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
	
	/* Calculate ROM size in K blocks and half-K Blocks (for header) */
	size_k = rom_size / 1024;
	size_half_k = size_k * 2;
	fprintf(stderr,"Size(bytes): %d, Size(K): %d\nSize(512 Byte Chunks): %02Xh\n",rom_size,size_k,size_half_k);
	
	/* Allocate memory and read the file */
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
	
	/* Determine number of ROMS contained in the file */
	num_roms=0;
	
	size_of_jrc_str = sizeof(jrc_str) / sizeof(jrc_str[0]);
	str = (char *)malloc(size_of_jrc_str);
	
	for (i = 0; i < size_of_jrc_str-1; i++){
		str[i] = rom[i];
	}
	str[size_of_jrc_str-1] = '\0'; /* Add null terminator */
	terminator1 = rom[size_of_jrc_str-1];
	terminator2 = rom[size_of_jrc_str];

	if (strcmp(jrc_str,str) == 0 && terminator1 == 0x0D && terminator2 == 0x0A){
		fprintf(stderr,"Found JRC header: %s,%02Xh,%02Xh\n",str,terminator1,terminator2);
		start_pos=512;
	}
	else {
		start_pos=0;
	}
	fprintf(stderr,"Start Position: %d\n",start_pos);
	free(str); /* Free memory */
	
	for (i = start_pos; i < rom_size; i++){
		sig1 = rom[i];
		sig2 = rom[i+1];
		
		if (sig1 == 0x55 && sig2 == 0xAA){
			num_roms++;
			rom_k_len=rom[i+2];
			end_of_rom=rom_k_len * 512;
			entry1=rom[i+3];
			entry2=rom[i+4];
			entry3=rom[i+5];
			
			orig_crc.LH.h=rom[i+end_of_rom-2];
			orig_crc.LH.l=rom[i+end_of_rom-1];
			fprintf(stderr,"Found ROM Signature(%d) at %04Xh\n\tLength: %02Xh Blocks\n\tEntry: %02Xh %02Xh %02Xh\n\tCRC: %02Xh %02Xh\n",num_roms,i,rom_k_len,entry1,entry2,entry3,(unsigned char)orig_crc.LH.h,(unsigned char)orig_crc.LH.l);
			fprintf(stderr,"  Validating current CRC..."); /* Intentionally no new-line */
			
			crc.x = check_crc(i,end_of_rom);
			
			if(crc.LH.h != 0 || crc.LH.l != 0){
				fprintf(stderr," Invalid. Expected 00h 00h, got: %02Xh %02Xh\n",(unsigned char)crc.LH.h,(unsigned char)crc.LH.l);
				rom[i+end_of_rom-2] = '\0';	
				rom[i+end_of_rom-1] = '\0';	

	
				fprintf(stderr,"  Zero'd CRC, attempting to regenerate checksum\n");
				crc.x = compute_crc(i,end_of_rom);
				fprintf(stderr,"  New Checksum calculation: %02X,%02X\n",(unsigned char)crc.LH.h,(unsigned char)crc.LH.l);

				rom[i+end_of_rom-2]=crc.LH.h;
				rom[i+end_of_rom-1]=crc.LH.l;
				
				fprintf(stderr,"Updated ROM Signature(%d) at %04Xh\n\tLength: %02Xh Blocks\n\tEntry: %02Xh %02Xh %02Xh\n\tCRC: %02Xh %02Xh\n",num_roms,i,rom_k_len,entry1,entry2,entry3,(unsigned char)crc.LH.h,(unsigned char)crc.LH.l);
			}
			else {
				fprintf(stderr," Valid.\n");
			}
			i+=end_of_rom-1;
		}	
		else {

			fprintf(stderr,"No ROM Signature Found at %04Xh, skipping 2K block\n",i);
			i+=2048-1;
		}
	}	
	
	/* Output - Currently only outputs raw cartridge */
	ofile = fopen(output_file_name,"wb"); 
	for (i = start_pos; i < rom_size; i++){
		fprintf(ofile,"%c",rom[i]);
	}
	close(ofile);
	free(rom); /* Free memory */
	
	return 0;
}
