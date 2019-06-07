# Arduino-Communication-Tutorial
This is the source for http://ask.jaimeyu.com/2011/10/arduino-tutorial-communication-protocol.html

# Arduino Tutorial: Communication Protocol

Two Arduinos talking over a TWI bus.
Picture taken from my CAPSTONE project


My friend Jon has a cool project he is working on. He has two Arduinos at home and he has one controlling some motors that points a camera around. Now he wants to network that Arduino with another so he can manually control the motors and share information.

He didn't find any good easy examples on how to write a network protocol for inter-Arduino communications, so this is why I'm writing this tutorial.

It will cover the basics and try to stay high level. As well, I tried to "future proof" the code so that it can be used as a baseline for other people.

I will make improvements over the week to clean it up but generally, not much in terms of logic will be changed.

Is this the best tutorial you will find? No, far from it. I would never use this code in production code. But I hope that it is written clearly enough that a novice programmer can learn something from this.

[COMPLETE SOURCE HERE]
Source at GitHub

The Problem

How to define and implement a serial communication protocol from scratch.

Background

I have written many different implementation for a serial network communication. So in this scenario, my friend wanted to make a communication protocol for his 2 Arduinos but wanted it to be portable. He noticed a lot of the protocols examples he found online were too specific for a particular project. So I decided to help him out and write this tutorial for him.

Let's lay down our requirements:
The protocol must be expandable. This means that it should not require a huge rewrite to add or remove variables. 
The protocol must be able to send at least one byte of necessary information. In my friend's project, this the X-Y coordinates his motors are using. So this means the protocol must be able to send one byte of X values at a time. 
Must be written in C and reuse as much standard Arduino libraries as possible. 
Be understandable for a novice programmer. Bet you will never see this on any corporate project's requirements. 
Specifics, aka specifications

The message will be called the data packet, or packet for short and we will be using fixed size packets for simplicity sake.

The packet will be 3 bytes large.

BYTE 1: COMMAND BYTE
BYTE 2: VARIABLE 1
BYTE 3: VARIABLE 2

Why 3 bytes? Because this is the perfect amount to explain some key concepts about communication protocols. At the end of this tutorial, I will explain the short comings of this protocol but because of modularity, you should be able to add the missing features. Those features are explicitly omitted in order to make the tutorial clearer. 

What is ... BYTE 1? This is the command byte. This byte will tell the receiving Arduino what the 2 other bytes in the message contain. So if we send a command, SAVE_LOC_X, the receiving Arduino will understand that it needs store BYTE 2, or VARIABLE 1, as a 1 byte variable. In my friend's setup, this will be location X along a 2D plane. 

SAVE_LOC_Y, will then complimentary mean that the receiving Arduino will need to save BYTE 2 as its Y location along a 2D plane.

Now, this can be a problem. Why do we want to send 2 packets for this data? It is rather inefficient because for every 1 update of X-Y locations, you will need to send 2 packets, with 2 different command bytes.

So we can simplify it by making a new command variable: SAVE_ALL. This will tell the receiving Arduino that BYTE 2 contains the X variable, and BYTE 3 contains the Y variable. 

This means we can now update both locations using 1 packet! We're much more efficient now!

Now, for practical purposes, my friend will want to send larger variables, such as 16 bit integers or even 32 bit floating point variables. Obviously, this won't fit in a single byte and needs to be simplified. 

In my implementation, I have the Arduino split a 16 bit variable into two 8 bit variables. There is an important note to why I did it this way. When dealing with binary variables, different micro controllers handle the storage of variables in different ways. This is called Endianness.  

Some Intel chips will store a 16 bit integer in memory as such: [LOW BYTE] [HIGH BYTE]
In other chips, it will be: [HIGH BYTE] [LOW BYTE]

Doesn't seem like a big deal but it is when you need to pass this information along a network. Different implementation of libraries will send the lower byte first and then send the high byte second. So this can cause us problems in the future. Luckily, we're only dealing with Arduino but from habit, I want to make the order it sends the bytes as part of the specifications. This is important for ensuring that when you implement this protocol on another chip, it has the expected behaviour. 

So for this project, the HIGH byte of a 16 bit variable will always be sent before the lower byte. 

We'll call this command as SAVE_LONG_X. 

Implementation

A quick note about my implementation. I choose some rather interesting values for my constants because I wanted to make my protocol human readable. This is very important when debugging. So almost all my hard constant will use a letter from the alphabet so a person can sniff the serial bus and be able to understand what is going on when the two Arduinos are talking. There is a size cost associated to this but luckily, my protocol only has 3 commands so I really have nothing to worry about. It means I'm limiting myself to only 26-52 (if you include capitals) possible commands by keeping them in the alphabet range. 

We will be using a button on the Arduino to trigger the messages. The button should be on pin 3 and triggers on a LOW to HIGH transition. 

A response to a correct message transmission will be when a 'z' is sent out by the receiving Arduino. To make this better, an LED should can be used instead but I didn't bother in my implementation. The point is not to see it working, but how it is working. So when you see a 'z' on the serial bus at the end of a message, it means the receiving Arduino validated the message. 

Lets initialize our variables and defines. 
const int baudRate = 9600;
I am defining the speed of the serial bus to 9600 using a const int instead of a #define. This is because of habit. #define is a compiler definition and tells the compiler to replace said variables with the value. The problem with this is that it is not type safe. What happens if I wanted to store the data into an 8 bit variable? 9600 wouldn't fit and it would get truncated. If you're unlucky, the compiler won't even throw a warning about this. 

Using const int ensure that the compiler can never make that mistake. It will definitely throw an error because you're trying to store an int into a byte. To be even safer, I should be using uint16_t instead of int as this is the correct way to specify the amount of bits I want for an int. This is important as a double is the same size as a long on an Arduino so using this template will make sure we can't accidentally create a 32 bit double when you meant to make a 64 bit double. 

Now for simplicity sake, I need to define my command bytes. I use an enum to do this because it is safer and easier to work with. Enum is short for enumerate and its function is to automatically assign values to a list of variables. 
enum COMMANDS {
  SAVE_LOC_X = 'a',
  SAVE_LOC_Y,
  SAVE_ALL,
  SAVE_LONG_X
};
The enum automatically assigned values to my constants as such. 
SAVE_LOC_X = 'a'
SAVE_LOC_Y = 'b'
SAVE_ALL = 'c'
SAVE_LONG_X = 'd'

This is useful because if I want to add new commands, I can add them to this list and it will assign them for me. The disadvantage to this method is that the assigned value can be larger than the destination size. Again, not a problem for our implementation. 

Now here is an interesting snippet, 
enum PACKET_DETAILS{
  CMD_LOC = 0,
  ITEM_1,
  ITEM_2,
};
What I did here was create some small helper variables for me to use. Since I know BYTE 1 will always be the location for the command byte, I assigned I a value of 0 (remember, 0 is a number in the computer and mathematical world). And so forth for the other byte locations. This is completely unnecessary but I like to do it this way to help keep the code clean. Plus, if I decide to increase the packet size, I can modify this enum and a lot of the code will still work as is. Ahhh, modularity. 

Now the data packet. This is important, so I created a structure to hold the data packet. 
struct
{
  byte data[BUFFER_LIMIT]; //this is where we will store the data we receive from the serial
  byte curLoc; //this is the counter to keep track of how many bytes we've received
} dataPacket;
Notice that the structure contains two item. An array buffer of 3 rows (BUFFER_LIMIT = 3) and a curLoc byte. data is an array of 3 bytes and this is where we will store our incoming packets into. The curLoc byte is used by the Arduino to track which byte it is currently processing from the serial bus. It does not need to be here but for clarity sake, I put it into this structure so you can see that this variable is closely related to the data buffer. 

Now we will have some state control bytes to keep track of what the Arduino is doing. 
bool correctPacket = false;
bool myButtonState = false;
unsigned long lastTimerHit;
correctPacket will turn true if the packet the Arduino receives is correct. myButtonState is just a simple state variable for the button to track when it goes from LOW to HIGH. And lastTimerHit is used to invalidate data if there is a gap in the transmission. If the receiving Arduino receives 2 bytes and then had to wait 760ms for the next byte, the Arduino will drop the old 2 bytes and use the latest byte as the beginning of a new packet. Again not necessary but useful when you are hand typing commands into the Arduino serial window. If you make a mistake, you can just wait for the Arduino to invalidate the message and begin anew. 

Function setup() is pretty much straight forward and initializes some variables to 0. 

Function loop() is really simple, well... to keep things simple. 

Function checkButton() checks the button transitions and if it catches a LOW to HIGH transition, it will send a message over the serial bus. 

Every time the button is pressed, I increment variable example_counter so the next message sent is of a different command. 

For the first case:
        case 0:
        curCommand = SAVE_LOC_X;
        //add custom code here if wanted.
        Serial.print(curCommand);
        Serial.print(var1);
        Serial.print('\n');
        break;
You can see that I first send the command, then the variable. Since we have to send exactly 3 bytes per packet, I filled the next variable with a new line character. The receiving Arduino will just ignore it but it cleans up the Arduino serial communication window when debugging. 
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
I don't think I need to explain the next few cases as they are basically the same but inserting different variables. 

Just some quick notes about the operators I used. 

>> is used to bit shift a variable's bit by n amount to the right.
<< is to shift by n amount to the left.
|= is a bitwise OR'ing operation. 
& is a bitwise AND operation. 
More information can be gathered here for C. 

Now it's time for checkIncomingSerial() function. This one is tricky and the one my friend wanted the most. We only call this function when the Arduino Serial library detects that its buffer has some data in it. When we first enter the function, I check if the message has timed out. 
if ( (lastTimerHit + 500) < millis() )
    {
      //if here, we hit the timeout, reset the packet counter
      dataPacket.curLoc = 0; //reset counter
      correctPacket = false;
      //Serial.println("timeout hit");
    }
If we hit the time out, then we reset the curLoc to 0 for our data array. This means we will start storing the data into data[0] on the next step.
dataPacket.data[dataPacket.curLoc] = Serial.read();
If we didn't time out, curLoc would contain the byte number we are at. 

Now we want to check if we collected 3 bytes by doing
if ( dataPacket.curLoc == BUFFER_LIMIT)
If we've received 3 bytes, then we can start processing the message. I use a switch function to check if the command byte matches 
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
So depending on the command byte, the Arduino will store the received data in the appropriate variables, such a locX. Notice that because I wrote it in a switch case statement, we can easily add more commands to process. Another really awesome feature of the switch case is that because I used an enum to generate the command values, the switch case will likely be optimized into a jump table which is small and fast. Check my old post about jump tables here. 

That is basically it for the explanation. I hope it was clear enough.

Epilogue

Here are some things I omitted from the protocol: variable length packets, addressing, and error detection. If you want to add more than one Arduino on the network and be able to transmit directly to one, you can assign each Arduino an address and have them add their address somewhere at the start of the message. Since its location will be fixed, every Arduino will be able to compare it to their address when a complete packet is transmitted. 

Error detection is a bit more tricky and I will cover that in another tutorial. This can be an extra byte in the message and is usually appended at the end of the packet. 

As an exercise, try to modify my code to add 2 more bytes to the message to be able to send 4 variables or a single 32 bit variable between Arduinos. As an advance exercise, you can try implementing addressing or error detection. Another simple exercise is to add support for the 'z' acknowledge message that I send out after every validated message. This can be quite useful, if the sender notices that he hasn't received an acknowledge, it can then repeat the message until it the receiver finally validates the message. 

Comments and fixes are welcomed. I wrote the code in about an hour so it isn't exactly fully tested. 
