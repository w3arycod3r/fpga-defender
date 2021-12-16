// Source: https://www.instructables.com/Creating-arcade-game-sounds-on-a-microcontroller/
// Author: JColvin91

int buzzerPin = 4;

void setup(){
  pinMode(buzzerPin, OUTPUT);
  //charge the missile
  for(int chargingFrequency=0; chargingFrequency<50; chargingFrequency++){
    playFreq(300.251+(chargingFrequency*15), 15);
  }
  delay(500);
  //fire the missile
  for(int missileFired=0; missileFired<20; missileFired++){
    playFreq(800.251-(missileFired*15), 10);
  }
  
  delay(1000);
  //explosion sound of random frequencies choosen off the 
  //top of my head
  playFreq(550, 40);
  playFreq(404, 40);
  playFreq(315, 40);
  playFreq(494, 40);
  playFreq(182, 40);
  playFreq(260, 40);
  playFreq(455, 40);
  playFreq(387, 40);
  playFreq(340, 40);
  playFreq(550, 40);    //begin repeat of the frequencies just played
  playFreq(404, 40);
  playFreq(315, 40);
  playFreq(494, 40);
  playFreq(182, 40);
  playFreq(260, 40);
  playFreq(455, 40);
  playFreq(387, 40);
  playFreq(340, 40);
  
  //wah, wah, wah, wahwawawawa
  for(double wah=0; wah<4; wah+=6.541){
    playFreq(440+wah, 50);        //'A4' gliss to A#4
  }
  playFreq(466.164, 100);         //A#4
  delay(80);
  for(double wah=0; wah<5; wah+=4.939){
    playFreq(415.305+wah, 50);    //Ab4 gliss to A4
  }
  playFreq(440.000, 100);          //A4
  delay(80);
  for(double wah=0; wah<5; wah+=4.662){
    playFreq(391.995+wah, 50);    //G4 gliss to Ab4
  }
  playFreq(415.305, 100);          //Ab4
  delay(80);
  for(int j=0; j<7; j++){          //oscillate between G4 and Ab4
    playFreq(391.995, 70);         //G4
    playFreq(415.305, 70);         //Ab4
  }
}//END of setup

void loop(){
  //do nothing in the loop for now; only testing in the setup
}


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


