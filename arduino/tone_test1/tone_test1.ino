// tone_test1: A sound effect sandbox for the "Arduino Apollo" with onboard Piezo on pin D9.

#include "pitches.h"  // must include open source pitches.h found online in libraries folder or make a new tab => https://www.arduino.cc/en/Tutorial/toneMelody
#define BUZZ_PIN 9

void setup() {

  Serial.begin(9600);
  // randomSeed(analogRead(0));
  pinMode(BUZZ_PIN, OUTPUT);
  //launch
  // for(long freqIn = 200; freqIn < 500; freqIn = freqIn + 2){
  //   tone(BUZZ_PIN, freqIn,10);
  // }
  // delay(10);

  // life lost test
  // long blow1;
  // long blow2;
  // long start_f = 300;
  // long stop_f = 50;

  // int i = -1;
  // long duration = 500;

  // long steps = 10;
  // long top = 1700;
  // long bottom = 100;
  // long offset_top = 300;
  // long offset_bottom = 20;
  // long offset_range = (offset_top - offset_bottom);
  // long offset_decr = offset_range / steps;
  // long offset = offset_top;
  // long range = (top - bottom);
  // long del = duration / steps;
  // long decr = range / steps;
  // long center = top;

  // for(int k = 0; k < steps; k++){
  //   long freq = center + i * offset;
  //   long duration = del;
  //   Serial.println(freq);
  //   Serial.println(duration);
  //   tone(BUZZ_PIN, freq, duration);
  //   delay(del);
  //   i *= i;
  //   center -= decr;
  //   offset -= offset_decr;
  // }

  // delay(2000);

  // randomly generated explosion sound
  randomSeed(500);
  Serial.println("-----random explosion------");
  int numSteps = 20;
  int totalDurationMsec = 500;
  int waitTime = totalDurationMsec / numSteps;

  for(int k = 0; k < numSteps; k++){
    int blow1 = random(100,500);
    // blow2 = random(5,10);
    tone(BUZZ_PIN, blow1, waitTime);
    delay(waitTime);

    Serial.println(blow1);
    Serial.println(waitTime);
  }

  delay(2000);

  // Play coin sound
//  tone(BUZZ_PIN,NOTE_B5,100);
//  delay(100);
//  tone(BUZZ_PIN,NOTE_E6,850);
//  delay(800);
//  noTone(8);
 
//  delay(2000);  // pause 2 seconds
//
//  // Play 1-up sound
//  tone(BUZZ_PIN,NOTE_E6,125);
//  delay(130);
//  tone(BUZZ_PIN,NOTE_G6,125);
//  delay(130);
//  tone(BUZZ_PIN,NOTE_E7,125);
//  delay(130);
//  tone(BUZZ_PIN,NOTE_C7,125);
//  delay(130);
//  tone(BUZZ_PIN,NOTE_D7,125);
//  delay(130);
//  tone(BUZZ_PIN,NOTE_G7,125);
//  delay(125);
//  noTone(8);

//  delay(2000);  // pause 2 seconds
//
//  // Play Fireball sound
//  tone(BUZZ_PIN,NOTE_G4,35);
//  delay(35);
//  tone(BUZZ_PIN,NOTE_G5,35);
//  delay(35);
//  tone(BUZZ_PIN,NOTE_G6,35);
//  delay(35);
//  noTone(8);
//  
//  delay(2000);  // pause 2 seconds

  //charge the missile
  // Serial.println("-----charge-----");
  // for(int chargingFrequency=0; chargingFrequency<50; chargingFrequency++){
  //   playFreq(300.251+(chargingFrequency*15), 15);
  // }
  // delay(500);
  // Serial.println("------fire------");
  // //fire the missile
  // for(int missileFired=0; missileFired<20; missileFired++){
  //   playFreq(800.251-(missileFired*15), 10);
  // }
  
  // delay(1000);
  // Serial.println("-------explosion-------");
  // //explosion sound of random frequencies choosen off the 
  // //top of my head
  // playFreq(550, 40);
  // playFreq(404, 40);
  // playFreq(315, 40);
  // playFreq(494, 40);
  // playFreq(182, 40);
  // playFreq(260, 40);
  // playFreq(455, 40);
  // playFreq(387, 40);
  // playFreq(340, 40);
  // playFreq(550, 40);    //begin repeat of the frequencies just played
  // playFreq(404, 40);
  // playFreq(315, 40);
  // playFreq(494, 40);
  // playFreq(182, 40);
  // playFreq(260, 40);
  // playFreq(455, 40);
  // playFreq(387, 40);
  // playFreq(340, 40);

  // Serial.println("-------wah, wah, wah, wahwawawawa---------");
  // //wah, wah, wah, wahwawawawa
  // for(double wah=0; wah<4; wah+=6.541){
  //   playFreq(440+wah, 50);        //'A4' gliss to A#4
  // }
  // playFreq(466.164, 100);         //A#4
  // Serial.println("0");
  // Serial.println("80");
  // delay(80);
  // for(double wah=0; wah<5; wah+=4.939){
  //   playFreq(415.305+wah, 50);    //Ab4 gliss to A4
  // }
  // playFreq(440.000, 100);          //A4
  // Serial.println("0");
  // Serial.println("80");
  // delay(80);
  // for(double wah=0; wah<5; wah+=4.662){
  //   playFreq(391.995+wah, 50);    //G4 gliss to Ab4
  // }
  // playFreq(415.305, 100);          //Ab4
  // Serial.println("0");
  // Serial.println("80");
  // delay(80);
  // for(int j=0; j<7; j++){          //oscillate between G4 and Ab4
  //   playFreq(391.995, 70);         //G4
  //   playFreq(415.305, 70);         //Ab4
  // }


}

void loop() {
  // tone(BUZZ_PIN, map(analogRead(0), 0, 1023, 30, 5000));
  delay(10);
}

void playFreq(double freqHz, int durationMs){
  Serial.println(round(freqHz));
  Serial.println(durationMs);
  //Calculate the period in microseconds
  int periodMicro = int((1/freqHz)*1000000);
  int halfPeriod = periodMicro/2;
   
  //store start time
  int startTime = millis();
   
  //(millis() - startTime) is elapsed play time
  while((millis() - startTime) < durationMs){
      digitalWrite(BUZZ_PIN, HIGH);
      delayMicroseconds(halfPeriod);
      digitalWrite(BUZZ_PIN, LOW);
      delayMicroseconds(halfPeriod);
  }
}
