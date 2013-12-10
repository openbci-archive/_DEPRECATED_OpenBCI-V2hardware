This Library opens communication between Arduino UNO and the ADS1299
SPI register fuses are directly set to match the ADS1299 interface requirements.
SCK rates: 1MHz, 4MHz, 8MHz. 
All registers and commands are fully accessable.
Here is a list of the functions and parameters available from the Library.



ADS1299.Initialize(int _DRDY, int _RST, int _CS, int _FREQ)
	Data Ready pin, Chip Select pin, and SCK frequency in MHz.
	the current shield uses DRDY = 8; RST 9 CS = 10.
	frequency options are 1MHz, 4MHz, 8MHz.
	bear in mind that at higher frequencies, appropriate delays
	must be taken when sending multiple bytes (DS p.37)
	initialization performs recommended timing and toggle of /RESET pin

//Public Variables

    int DRDY, CS; 		// pin numbers for DRDY and CS 
	These are part of the constructor
	they are not implemented in the current library
	but could be useful in future member functions

    int stat;			// used to hold the status register
	the status register is the first byte returned when you read channel data
	it has 1100 + LOFF_STATP + LOFF_STATN + GPIO[7:4]

    byte regData [24];		// array is used to mirror register data
	this array is used to write multiple locations of ADS register data using WREGS()
	user must first assign target values to the corresponding locations in regData aray
	a call to RREGS() will read multiple locations and update regData array
  
    long channelData [9];	// array used when reading channel data
    boolean verbose;		// turn on/off Serial feedback


//System Commands   

    void WAKEUP();	// wakeup from standby mode
    void STANDBY();	// go into standby mode
    void RESET();	// reset all registers to default values
    void START();	// start a data conversion session
    void STOP();	// stop data conversion

	timed delays are taken where required in the above funcitons. 
	bear in mind the timing of your byte to byte transmission.
	clk on ADS is ~2MHz, so that is a limit.
    
//Data Read Commands

    void RDATAC();	
	enter Read Data Continuous mode
	Read Data Continuous mode enables the ADC and shift registers
	in this mode, you can start a sampling session by setting the start pin,
	or sending the start command

    void SDATAC();	
	enter Stop Read Data Continuous mode
	this mode will let you write and read registers

    void RDATA();	
	Read Data command is used when you're in Stop Read Data Continuous mode
	if you send or set the 'start' command, this allows you to sample on DRDY
	and also have access to read/write the registers. see DS p.37 
    
//Register Read/Write Commands	

    byte getDeviceID();
	simple hello world to check that the device is working properly
	returns 0x3E on the Dev Module I'm using.
	must be in Stop Data Continuous mode prior to sending this

    byte RREG(byte _address);
	returns the value of one register address, specified
	the funcion also updates regData at _address

    void RREGS(byte _address, byte _numRegistersMinusOne);     
	updates the public regData array with current values
	_address is the address to start reading at
	_numRegistersMinusOne is the number of registers to read past the _address
	NOTE: the public regData array behaves like a mirror of the ADS internal arrays,
	however, the user must update the mirror. 

    void printRegisterName(byte _address);
	this is a look up table. part of the verbose feedback and not used external to the library

    void WREG(byte _address, byte _value); 
	writes a single value specified by _value to the register address at _address.

    void WREGS(byte _address, byte _numRegistersMinusOne); 
	writes a number of values to sequential addresses starting at _address
	user must first set values in correct locations of the public byte array regData
	regData is a mirror of the ADS register values

    void printHex(byte _data);
	used to streamline verbose feedback 

    void updateChannelData();
	the public array, channelData[8] gets updated, along with the status register.
	there is bitwise conversion from 3 byte 2's compliment to 4 byte 2's compliment (long)
    
//SPI Transfer function

    byte transfer(byte _data);
	puts the byte _data on the SPI bus, and returns a byte from the SPI bus.


//KNOWN ISSUES

	verbose feedback in the updateChannelData() function bumps against the DRDY signal
	this is because 115200 baud can't keep up?

	
//USING THIS LIBRARY
	
	The START pin is not broken out. You must send the START() command instead.
	For daisy-chaining in the future, we will route a GPIO to the START pin and 
	header socket.

	You must remeber to get out of Read Data Continuous mode if you want 
	to read/write, and do other register things.


