// Source: https://www.instructables.com/Creating-arcade-game-sounds-on-a-microcontroller/
// Author: JColvin91

/***************************************************************************/
/*								           */
/*      This is a project inspired by Hamster's own "Colour Invaders"      */
/*                          project available at                           */
/*      http://hamsterworks.co.nz/mediawiki/index.php/Colour_Invaders      */
/*    									   */
/*      This project uses a chipKIT uC32 microcontroller board, the        */
/*      PmodENC to act as a rotary encoder, a strip of 30 WS2812 LEDs,     */
/*      and of course wires to get everything connected.                   */
/*     									   */
/*      To play the game, rotate the encoder shaft to have your missile    */
/*      color match that of the first oncoming invader. Once they match,   */
/*      press the shaft button to fire your missile and destroy the        */
/*      invader. You'll need to wait for the next missile to charge up     */
/*      before being able to fire at the next invader coming down the      */
/*      strip at a faster rate.                                            */
/*    									   */
/*      Luckily for us, if we successfully destroy enough invaders in      */
/*      a row we'll get a nice little bonus... :)                          */
/*    									   */
/*    	You can enable (or disable) sound for this game by adding a        */
/*      small pwm speaker to digital pin 28 and setting to boolean         */
/*      "enableSound" to true (or false) in the setup function.            */  
/*    									   */
/*      Can you survive the onslaught of the Color Invaders?!	  	   */
/*									   */
/***************************************************************************/


/*********************************************************/
/*                                                       */
/*     Necessessary libraries and other declarations     */
/*                                                       */
/*********************************************************/
#include <ENC.h>
#include <PICxel.h>


#define numberOfLEDs 30
#define LED_pin 3

#define missileCharging 750  //charging time in milliseconds
#define missileSpeed 25       //missile speed per pixel in milliseconds

//PICxel constructor(uint8_t # of LEDs, uint8_t pin #, color_mode GRB or HSV);
PICxel strip(numberOfLEDs, LED_pin, HSV);
uint8_t sat = 255;
uint8_t value = 60;
uint8_t chargingSat = 125;
uint8_t chargingVal = 20;

ENC myENC;

// pin number of the pin that BTN is attach to 
int btn = 30; 
//determine which way the encoder was rotated
volatile int i;

//game variables
////invaders variables
uint16_t invaders[numberOfLEDs];           //invaders array holding the colors
int invaderDelay = 3000;          //invaders move every 3000 ms (will be decreased as game progresses)
int numberOfInvaders = 0;        //how many invaders are currently present
int invaderDelayTime;            //global variable to hold how long it has been since the invader last moved

////missile variables
uint16_t missileLocation = 0;     //start at the first spot
boolean missileExists = false;    //boolean for the missile existence
boolean missileInFlight = false;  //boolean for the in-flight missile
int chargingTime;                 //global variable to hold the charging time
int missileDelay;                 //global variable to hold how long it has been since the missile has last moved
uint16_t missileColor;            //initialize the missile color that can be changed
uint16_t missileInFlightColor;    //initialize the missile color in flight that will be constant

////other variables
int numberOfSuccessfulHits = 0;   //keeping track of how many hits we have scored to see if we get a superShot
uint16_t superShotHue;            //what the current color of the superShot is
boolean superShot = false;        //boolean for the superShot

////sound variables
int buzzerPin = 28;
int chargingFrequency = 0;      //frequency noise variable for charging up the missile
int firingFrequency = 0;        //frequency noise variable for firing the missile
boolean enableSound = false;      //by default, there is no sound for this game


/********************************************************/
/*                                                      */
/*                   Setup Function                     */
/*                                                      */
/********************************************************/
void setup() {
  enableSound = true;  //turn on the sound for this game
  pinMode(buzzerPin, OUTPUT);

  i = 0;
  Serial.begin(9600);
  Serial.println("Can you survive the attack of the Color Invaders?");
  Serial.println('\n');
  Serial.println("Project inspired by hamster at http://hamsterworks.co.nz/mediawiki/index.php/Colour_Invaders");
  Serial.println('\n');
  Serial.println("Twist the encoder shaft to match the color of the oncoming invader and then press the button shaft to fire the shot");
  Serial.println("After a shot has been fired, you will need to wait for the cannon to recharge before being able to shoot another shot");
    
  //set swt and btn as input
  pinMode(btn, INPUT);
    
  //Set LD2 to output
  pinMode(PIN_LED2, OUTPUT);
    
  //Call begin to initialize the change notices for pin A and Pin B
  //in this example CN2 is used for pin A and CN3 for pin B
  myENC.begin(8, 9);
  //Assigns the passed in function to the end of the Interrupt Service 
  //Procedure so that every time the encoder turns the function will be 
  //called passing the direction the encoder
  myENC.AttachInterrupt(changeColor);
  //initializing the WS2812 LED strip library code
  //start the code and clear the strip of any colors
  strip.begin();
  strip.clear();
  strip.refreshLEDs();
  //Some initial code to get things on the strip of LEDs
  //this will also help with the timing later on
  //Start out placing our missile
  uint16_t missileColor;
  if(missileExists == false){
    missileColor = currentColor(i);
    chargingTime = millis();
    missileExists = true;
    strip.HSVsetLEDColor(0, missileColor, chargingSat, chargingVal);
  }
  //then place our first invader
  uint16_t invaderColor = randomColor();
  invaders[numberOfLEDs-1] = invaderColor;
  numberOfInvaders++;
  strip.HSVsetLEDColor((numberOfLEDs-numberOfInvaders), invaderColor, sat, value);
  invaderDelayTime = millis();
  //update the whole display
  strip.refreshLEDs();
  updateMissileColor();
}//END of setup


/********************************************************/
/*                                                      */
/*                    Loop Function                     */
/*                                                      */
/********************************************************/
void loop() {  
  //update the color of the missile; don't change it if the missile is in flight (unless it's a superShot)
  if(missileExists == true && (missileInFlight == false || superShot == true)){
    updateMissileColor();
  }//END of checking to see if we update the missile color
  
  //allows user to prepare for the next invader color without changing the current missile color while in flight
  if(missileInFlight == true){
    missileColor = currentColor(i);
  }//END of updating missileColor without actually changing the onscreen missile

  //if a missile is not in existence, choose a new color and start charging
  if(missileExists == false){
    generateMissile();
  }//END of checking to see if we create the missile
  
  //check to see if the missile is recharged, if so, fire!
  if(digitalRead(btn) && ((millis()-chargingTime)>missileCharging) && missileInFlight == false){
    fireMissile();
    strip.refreshLEDs();
    delay(1);
    if(firingFrequency<10 && enableSound == true){
      playFreq(800-(firingFrequency*20), 15);
      firingFrequency++;
    }
  }//END of checking to see if we fire the missile
  
  //check to see if it is time to move the missile along the strip
  if(missileInFlight == true && ((millis()-missileDelay)>missileSpeed)){
    moveMissile();
    if(firingFrequency<10 && enableSound == true){
      playFreq(800-(firingFrequency*20), 15);
      firingFrequency++;
    }
  }
  
  //check for contact on any LED value greater than 1
  if(missileInFlight == true && missileLocation == (numberOfLEDs-numberOfInvaders)){
    missileContact();
  }//END of checking for missile contactIf
  
  //check to see if it is time to move the invaders
  if((millis()-invaderDelayTime)>invaderDelay){
    moveInvaders();
  }//END of checking to see if it is time to move the invaders
  
  //check to see if the invaders have reached the first LED 0
  if((numberOfLEDs-numberOfInvaders)==0){
    loseTheGame();   //if invaders have won, lose the game; see user defined function for more details
  }
    
  //check for contact on any LED value greater than 1
  if(missileInFlight == true && missileLocation == (numberOfLEDs-numberOfInvaders)){
    missileContact();
  }//END of checking for missile contact
  
  //refresh the strip with new color values
  strip.refreshLEDs();
  delay(1);
}//END of loop

/********************************************************/
/*                                                      */
/*                User Defined Functions                */
/*                                                      */
/********************************************************/


/*************************************/
/*                                   */
/*       changeColor function        */
/*                                   */
/*************************************/
//interrupt routine of PmodENC that changes the color of missile
void changeColor(int dir)
{
  i += dir;
  if(i>5) i=0;
  else if(i<0) i=5;
}//END of changeColor

uint16_t currentColor(int currentValue){
  uint16_t hueColor;
  switch(currentValue){
    case 0: hueColor = 0; break;      //red
    case 1: hueColor = 1280; break;   //magenta/pink
    case 2: hueColor = 555; break;    //green
    case 3: hueColor = 111; break;    //orange
    case 4: hueColor = 981; break;    //blue
    case 5: hueColor = 751; break;    //cyan
    default: break;
  }   
  return hueColor;
}//END of currentColor

/*************************************/
/*                                   */
/*       randomColor function        */
/*                                   */
/*************************************/
//choose a color for the new color invader
uint16_t randomColor(){
  uint16_t hueColor;                  //the hue to return--saturation and value will remain at a set value
  randomSeed(millis());               //generate our random spot in the 32-bit number stream
  int colorCase = random(0,6);
  switch(colorCase){                  //determine which of the 6 main color options we have choosen
    case 0: hueColor = 0; break;      //red
    case 1: hueColor = 1280; break;   //magenta/pink
    case 2: hueColor = 555; break;    //green
    case 3: hueColor = 111; break;    //orange
    case 4: hueColor = 981; break;    //blue
    case 5: hueColor = 751; break;    //cyan
    default: break;
  }   
  return hueColor;
}//END of randomColor

/*************************************/
/*                                   */
/*    updateMissileColor function    */
/*                                   */
/*************************************/
void updateMissileColor(){
  missileColor = currentColor(i);
  //if the missile is done charging, do full saturation value
  if((millis()-chargingTime)>missileCharging && superShot == false){
    strip.HSVsetLEDColor(missileLocation, missileColor, sat, value);
  }
  //if we are working with a super shot
  else if(superShot == true){
    superShotHue +=15;
    if(superShotHue >1535){superShotHue = 0;}
    strip.HSVsetLEDColor(missileLocation, superShotHue, sat, value);
  }
  //smaller saturation value if it is not done charging yet and not a superShot
  else{
    if(chargingFrequency<100 && enableSound == true){
      playFreq(300+(chargingFrequency*8), 10);
      chargingFrequency++;
    }
    strip.HSVsetLEDColor(missileLocation, missileColor, chargingSat, chargingVal);
  }
}//END of updateMissileColor

/*************************************/
/*                                   */
/*      generateMissile function     */
/*                                   */
/*************************************/
void generateMissile(){
  //if we have successfully hit 10 targets in a row, power up a super shot
  if(numberOfSuccessfulHits !=0 && numberOfSuccessfulHits % 10 == 0){
    missileLocation = 0;
    superShot = true;
    missileExists = true;
    superShotHue = currentColor(i);
    strip.HSVsetLEDColor(missileLocation, superShotHue, sat, value);
    chargingTime = 0;    //set an instantaneous charging time
    if(enableSound == true){
      playFreq(659.255, 75);
      playFreq(783.991, 75);
      playFreq(1046.500, 75);
    }
  }
  //otherwise, it's just a normal shot
  else{
    missileColor = currentColor(i);
    missileLocation = 0;
    strip.HSVsetLEDColor(missileLocation, missileColor, chargingSat, chargingVal);
    chargingTime = millis();
    missileExists = true;
    chargingFrequency = 0;
    firingFrequency = 0;
  }
}//END of generateMissile

/*************************************/
/*                                   */
/*        fireMissile function       */
/*                                   */
/*************************************/
void fireMissile(){
  while(digitalRead(btn)){}//wait while the button is being held down
  delay(1);    //poor man's version of debouncing
  if(superShot == true){
    missileInFlight = true;
    missileLocation++;
    strip.HSVsetLEDColor(missileLocation, superShotHue, sat, value);
    strip.clear(missileLocation-1);
    missileDelay = millis();
  }
  else{
    missileInFlightColor = currentColor(i);
    missileInFlight = true;
    missileLocation++;
    strip.HSVsetLEDColor(missileLocation, missileInFlightColor, sat, value);
    strip.clear(missileLocation-1);
    missileDelay = millis();
  }
}//END of fireMissile

/*************************************/
/*                                   */
/*        moveMissile function       */
/*                                   */
/*************************************/
void moveMissile(){
  if(superShot == true){
    missileLocation++;
    strip.HSVsetLEDColor(missileLocation, superShotHue, sat, value);
    strip.clear(missileLocation-1);
    missileDelay = millis();
  }
  else{
    missileLocation++;
    strip.HSVsetLEDColor(missileLocation, missileInFlightColor, sat, value);
    strip.clear(missileLocation-1);
    missileDelay = millis();
  }
}//END of moveMissile

/*************************************/
/*                                   */
/*       missileContact function     */
/*                                   */
/*************************************/
void missileContact(){
  //if contact has occurred, check to see if the colors match
  if(missileInFlightColor == invaders[numberOfLEDs-numberOfInvaders]){
    explode();     //what it sounds like; see user defined function for more details
  }
  else if(superShot == true){
    explode();
  }
  //in case the missile somehow made it to the end of the strip without any invaders appearing...
  else if(missileLocation == numberOfLEDs){
    missileInFlight = false;
    missileExists = false;
    numberOfSuccessfulHits = 0;
    superShot = false;
    strip.clear();
    strip.refreshLEDs();
  }
  else{
    //missile disspears, flags and counters reset, invaders continue
    missileInFlight = false;
    missileExists = false;
    numberOfSuccessfulHits = 0;
    strip.HSVsetLEDColor((numberOfLEDs-numberOfInvaders), invaders[numberOfLEDs-numberOfInvaders], sat, value);
    strip.refreshLEDs();
  }
}//END of missileContact

/*************************************/
/*                                   */
/*         explode function          */
/*                                   */
/*************************************/
void explode(){
  missileInFlight = false;
  missileExists = false;
  superShot = false;
  invaderDelay = invaderDelay - 100;    //decrease how long the invaders wait to move
  numberOfSuccessfulHits++;
  numberOfInvaders--;          //decrease the total number of invaders
  strip.HSVsetLEDColor(missileLocation, 981, 1, 125);    //blinding white light
  strip.refreshLEDs();
  if(enableSound == true){
    playFreq(550, 40);
    playFreq(404, 40);
    playFreq(315, 40);
    playFreq(494, 40);
    playFreq(182, 40);
    playFreq(260, 40);
    playFreq(455, 40);
    playFreq(387, 40);
    playFreq(340, 40);
    playFreq(550, 40);
    playFreq(404, 40);
    playFreq(315, 40);
    playFreq(494, 40);
    playFreq(182, 40);
    playFreq(260, 40);
    playFreq(455, 40);
    playFreq(387, 40);
    playFreq(340, 40);
    delay(250);
  }
  else{
    delay(1000);
  }
  invaderDelayTime = millis();        //reset how long it is until the invaders move again
  strip.clear((numberOfLEDs-numberOfInvaders-1));
  strip.refreshLEDs();
  delay(1);
}//END of explode

/*************************************/
/*                                   */
/*      moveInvaders function        */
/*                                   */
/*************************************/
void moveInvaders(){
  numberOfInvaders++;          //increase the total number of invaders
  //for every invader up until the last invader on the strip (that has to be created anyway),
  //set the lower spot on the strip to the next higher spot on the strip
  for(int invaderLocation = (numberOfLEDs-numberOfInvaders); invaderLocation<(numberOfLEDs-1); invaderLocation++){
    invaders[invaderLocation] = invaders[invaderLocation+1];
    strip.HSVsetLEDColor(invaderLocation, invaders[invaderLocation], sat, value);
  }
  //create a new invader for the last spot on the strip
  uint16_t invaderColor = randomColor();
  invaders[numberOfLEDs-1] = invaderColor;
  strip.HSVsetLEDColor((numberOfLEDs-1), invaders[numberOfLEDs-1], sat, value);
  invaderDelayTime = millis();
}//END of moveInvaders

/*************************************/
/*                                   */
/*       loseTheGame function        */
/*                                   */
/*************************************/
void loseTheGame(){
  //reseting all of the flags and counts
  missileInFlight = false;
  missileExists = false;
  superShot = false;
  numberOfSuccessfulHits = 0;
  missileLocation = 0;
  numberOfInvaders = 0;
  invaderDelay = 5000;
  chargingFrequency = 0;
  firingFrequency = 0;
  strip.clear();
  
  //show the red glow
  for(int lose = 0; lose<10; lose++){
    strip.HSVsetLEDColor(lose, 0, sat, (value - lose*5));
  }
  strip.refreshLEDs();
  if(enableSound == true){
    delay(400);
    //wah wah wah wahwahwahwahwahwah
    for(double wah=0; wah<4; wah+=6.541){
      playFreq(440+wah, 50);
    }
    playFreq(466.164, 100);
    delay(80);
    for(double wah=0; wah<5; wah+=4.939){
      playFreq(415.305+wah, 50);
    }
    playFreq(440.000, 100);
    delay(80);
    for(double wah=0; wah<5; wah+=4.662){
      playFreq(391.995+wah, 50);
    }
    playFreq(415.305, 100);
    delay(80);
    for(int j=0; j<7; j++){
      playFreq(391.995, 70);
      playFreq(415.305, 70);
    }
    delay(400);
  }
  else{
    delay(1000);
  }
  strip.clear();
  strip.refreshLEDs();
  
  
  //reset the game like we do in the setup() function
  //start up the missile
  uint16_t missileColor;
  if(missileExists == false){
    missileColor = currentColor(i);
    chargingTime = millis();
    missileExists = true;
    strip.HSVsetLEDColor(0, missileColor, chargingSat, chargingVal);
  }
  //then re-place our first invader
  uint16_t invaderColor = randomColor();
  invaders[numberOfLEDs-1] = invaderColor;
  numberOfInvaders++;
  strip.HSVsetLEDColor((numberOfLEDs-numberOfInvaders), invaderColor, sat, value);
  invaderDelayTime = millis();
  //update the whole display
  strip.refreshLEDs();
}//END of loseTheGame

void playFreq(double freqHz, int durationMs){
  //Calculate the period in microseconds
  int periodMicro = int((1/freqHz)*1000000);
  int halfPeriod = periodMicro/2;
   
  //store start time
  int startTime = millis();
   
  //(millis() - startTime) is elapsed play time
  while((millis() - startTime) < durationMs){
    digitalWrite(buzzerPin, HIGH);
    delayMicroseconds(halfPeriod);
    digitalWrite(buzzerPin, LOW);
    delayMicroseconds(halfPeriod);
  }
}
