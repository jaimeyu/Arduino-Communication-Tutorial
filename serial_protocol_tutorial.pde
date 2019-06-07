/*
    Serial communication protocol tutorial
    Copyright (C) 2011 Jaime Yu
    www.jaimeyu.com || ask.jaimeyu.com 
    Built for my tutorial on Serial protocols: http://s.jaimeyu.com/yaS7 

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.


*/

//set the baudrate
const int baudRate = 9600;

//setup the command list
//we'll start at the character a, not 0
//so it would be human readable
//when you debug.
enum COMMANDS {
  SAVE_LOC_X = 'a', 
  SAVE_LOC_Y,
  SAVE_ALL,
  SAVE_LONG_X
};

//how big should our messages be?
//in this case, 3 bytes
//1 for command
// then 1 for the value
//the next byte is optional, 
//if you want to send a 16 byte variable.
const int BUFFER_LIMIT = 3;

//the variables in question
byte locX, locY; //8 bit large vars
unsigned int longLocX; //16 bits vars

//the following are just helpers for the datapacket
//the first byte will always be the command byte
//while item 1 and 2 are where the values will reside
enum PACKET_DETAILS{ 
  CMD_LOC = 0,
  ITEM_1,
  ITEM_2,
};

//this is the data packet structure. 
//This is where we will keep all the necessary data fo keep track of the
//incoming data. 
struct
{
  byte data[BUFFER_LIMIT]; //this is where we will store the data we receive from the serial
  byte curLoc; //this is the counter to keep track of how many bytes we've received
} dataPacket;

//default LED stuff
const int defaultLed = 13; //this is the default LED on pin 13
int defaultLedState = 0;

//button state
const int myButtonPin = 3;

//this tracks the state of the current message
bool correctPacket = false;
bool myButtonState = false;

//this is used for the timeout
//the arduino will reset its packet counter if it
//finds a gap of over 500ms between incoming bytes. 
unsigned long lastTimerHit;

//setup the variables to their default values;
void setup()
{
  Serial.begin(baudRate);
  pinMode(defaultLedState, OUTPUT);
  pinMode(myButtonPin, INPUT);

  dataPacket.curLoc = 0;
  locX = 0;
  locY = 0;

  correctPacket = false;

  Serial.println("Ready");
  lastTimerHit = 0;
}

void loop()
{
  if ( Serial.available() > 0)
  {
    checkIncomingSerial(); //plug it into state machine.
  }
  
  checkButton(); //check if the button is pressed

}

void checkButton()
{
  //everytime you press the button, it will now
  //send a different command message each time. 
  static int example_counter; 
  //Hey, what is this static keyword doing here?
  //I really do not want any other function in this application to
  //be able to use this variable so I made it static to this function. 
  //This means the variable can only be used/seen by this function
  //and when the function is finished, the variable isn't "zero'd"
  //Its content is preserved when the function is called again.
  
  int curCommand; //this holds the command we're going to send
  
  //we're going to initialize and set the variables for transmissions here
  //you can replace them with millis() or even analogRead()
  //if you want to get dynamic data.
  //But for teaching purposes, I will use a predictable set of data. 
  int long_X = 0;
  //quick hack to make long_X humand readable during transmission
  long_X = '5';
  long_X |= (int) ('g' << 8);
  
  
  byte var1 = 'W';
  byte var2 = 'B';
  
  //get button status
  int curButtonState = digitalRead(myButtonPin);
  
  //if button is pressed down, send 'a12' as an example
  if ( (myButtonState == false) && (curButtonState == HIGH) )
  {
    myButtonState = true; //set button state as on 
    //Serial.print("a12"); //send 'a12' out
    
    switch(example_counter)
    {
      case 0:
        curCommand = SAVE_LOC_X; 
        //add custom code here if wanted.
        Serial.print(curCommand);
        Serial.print(var1);
        Serial.print('\n');
        break;
      case 1:
        curCommand = SAVE_LOC_Y; 
        //add custom code here if wanted.
        Serial.print(curCommand);
        Serial.print(var2);
        Serial.print('\n');
        break;
      case 2:
        curCommand = SAVE_ALL; 
        //add custom code here if wanted.
        Serial.print(curCommand);
        Serial.print(var1);
        Serial.print(var2);
        break;
      case 3:
        curCommand = SAVE_LONG_X; 
        // 16 bit integers need to be conditioned for transfer.
        // we have to split the 16 bit variable into multiple (2) 8 bit messages.
        // Yes, we can cheat and use Serial.print("string") to send multi-byte variables.
        // I don't like doing this because of endian issues you may encounter when
        // porting this code to another microcontroller. 
        Serial.print(curCommand);
        Serial.print( (byte)(long_X >> 8) ); //only send the upper byte of the integer
        Serial.print( (byte)(longX & 0xFF) ); //isolate just the lower byte now.
        //the (byte) is a typecase to ensure that we only print 8 bits and not 16 by accident. 
        break;
      default:
        Serial.println("CRASH!");
        while(1)
        {
          digitalWrite(defaultLed,HIGH); //get stuck here
        }
        break;  
    }
    example_counter++;
    example_counter %= 3; //make sure the example counter is never over 3;
    
  }
  
  //if button is let go, reset button state
  if ( (myButtonState == true) && (curButtonState == LOW) )
  {
    myButtonState = false;
  }
}

void checkIncomingSerial()
{
  //check timeout, make sure there is not a large gap between bytes. 
  if ( (lastTimerHit + 500) < millis() )
    {
      //if here, we hit the timeout, reset the packet counter
      dataPacket.curLoc = 0; //reset counter
      correctPacket = false;
      //Serial.println("timeout hit");
    }
    
    //update the timeout timer
    lastTimerHit = millis();
    
    //get the byte from the serial buffer
    //and then store it into the packet buffer
    dataPacket.data[dataPacket.curLoc] = Serial.read();
    //Serial.println(dataPacket.data[dataPacket.curLoc]);

    //update the counter
    dataPacket.curLoc++;
  
    //check if the counter read 3 bytes in quick sucession
    if ( dataPacket.curLoc == BUFFER_LIMIT)
    {
      //assume the packet is correct. 
      correctPacket = true;
      //reset the counter, can be here or at the end.
      dataPacket.curLoc = 0;
      
      //check the first byte in the packet
      //we want to see if it is a valid command message
      //if it isn't, the message will be dumped
      //if it is, then we'll respond with a 'z'
      //
      switch ( dataPacket.data[CMD_LOC] )
      {
      case SAVE_LOC_X:
        locX = dataPacket.data[ITEM_1];
        break;

      case SAVE_LOC_Y:
        locY = dataPacket.data[ITEM_1];
        break;

      case SAVE_ALL:
        locX = dataPacket.data[ITEM_1];
        locY = dataPacket.data[ITEM_2];  
        break;

      case SAVE_LONG_X: //special case for 16 bit integers
        //WATCH OUT FOR ENDIANS!
        longLocX = 0;
        longLocX |= dataPacket.data[ITEM_1];
        longLocX << 8; //move over 1 byte
        longLocX |= dataPacket.data[ITEM_2];
        break;

      default:
        //if here, the command byte is wrong
        //so dump the current dataPacket by
        // resetting the counter
        
        correctPacket = false;
        dataPacket.curLoc = 0; 
        Serial.println("Err!");
        break;          
      }
    
      //now that we're done checking and processing the packet
      //for diagnostic purposes, we will send a 'z'
      //to tell the arduino that we've received the message. 
      
      //quick note: Not actually using this in the arduino code.
      //It is only for me (and you)
      //to be able to sniff the serial lines
      //to see if the packet arrived correctly. 
      if (correctPacket == true )
      {
        Serial.print("z\n");
        correctPacket = false;
      }

    }
}


