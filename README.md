# fpga-defender
This project was created for Dr. J. W. Bruce's [Digital System Design](http://jwbruce.info/teaching/ece4110/) class at [Tennessee Technological University](https://www.tntech.edu/engineering/programs/ece/).

# Demo

<p align="center">
  <img src="img/demo1.gif" width=450> <img src="img/demo2.gif" width=450>
</p>

[Video with sound](https://www.youtube.com/watch?v=Bie1J2sb7rM)
# Specification
Create a simplified, stylized version of the 1981 arcade classic [*Defender*](https://en.wikipedia.org/wiki/Defender_(1981_video_game)) for the [DE10-Lite](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=1021) MAX 10 FPGA dev board. The video output is 640x480 @ 60 Hz over [VGA](https://en.wikipedia.org/wiki/Video_Graphics_Array). The ship is controlled using the on-board accelerometer. Tilting the board from the horizontal will move the ship up, down, left, and right. On-board pushbuttons control game start, pause, and ship fire. Sound effects are played on an attached piezo buzzer. The score is displayed at the top right of the screen, and the current number of lives is shown at the top left. Also, the score and lives are indicated on the 7-segment displays and LEDs on-board.

<p align="center">
  <img src="img/board.jpg" width=450>
</p>

Dr. Bruce's original specification is shown in [f21_spec.pdf](docs/f21_spec.pdf)

# Gameplay
Enemies spawn in from the right. The spawning is random, using a [LFSR](https://en.wikipedia.org/wiki/Linear-feedback_shift_register) pseudorandom number generator. With each spawn, a random enemy "variant" and location is chosen. Each "variant" consists of a sprite and a scale factor. Points are awarded for destroying the enemies. More points are awarded for smaller enemies. As your score increases, the "stage" is increased. In later stages, more enemies are on-screen at once and the enemy speed is increased. Colliding with an enemy results in a lost life. When all lives are lost, the game is over. Every 500 points, an extra life is awarded.

# Sound Effects
The [effect_gen](bonuses/proj1/sound_effects/effect_gen.vhd) module controls the piezo buzzer. This module is a [FSM](https://en.wikipedia.org/wiki/Finite-state_machine) that read a simple "program" from an initialized [BRAM](https://www.nandland.com/articles/block-ram-in-fpga.html) in the FPGA. The [program](bonuses/proj1/res/effect_mem.mif) is simply a list of frequencies and durations to be played on the buzzer that make a sound effect.

# Sprites
The sprites are drawn using the [sprite_draw](bonuses/proj1/sprite_draw.vhd) module. This module was heavily inspired by the SystemVerilog code and ideas presented in the Project F [FPGA Graphics blog](https://projectf.io/posts/fpga-graphics/). I ported much of the author's code to VHDL and made modifications for my use case. I learned so much from this blog and I am grateful to the author for their open-source contributions. These sprites are used for the enemies, ship, and the large text on the title screen. The actual sprite [images](bonuses/proj1/res/sprite_data.mif) are heavily based on the original *Defender* sprites. I used palettized color with 16 [colors](bonuses/proj1/res/palette.mif) for simplicity.

# Text
For the smaller text, I utilized the very friendly module [FP-V-GA Text](https://github.com/MadLittleMods/FP-V-GA-Text). I had to make a minor modification to their code to work with the pixel clock, instead of 2x the pixel clock.

# Starfields
Again, I was inspired by the Project F [blog](https://projectf.io/posts/fpga-ad-astra/) for the [starfield](bonuses/proj1/starfield.vhd) module. This module works by using another LFSR, reading out the sequence to determine each pixel of the starfield, as well as its brightness. The LFSR is reset at a certain count value in order to get the "scrolling" effect. One modification I made was to allow the starfield to be "frozen" in place. There are three layered starfields, each having different speeds and densities.

# Smoothness
The screen captures shown in the "Demo" section are quite choppy and full of visual glitches. This is due to the low-quality capture hardware available on a fixed budget :) The actual output on a VGA monitor is actually quite smooth (60 FPS), sharp, and devoid of graphical artifacts or tearing. Surprisingly, this was done without framebuffering. Each pixel is drawn "just-in-time" based on all the game objects' current state. I simply restricted all object "state" updates to the end of the frame, i.e. during the blanking interval, when the screen is not actively drawing the frame. All updates are done before the drawing of the next frame begins, so there is no tearing.

# Collision Detection
Position and size data (yielding a "hitbox") for each game object is stored in registers (DFF's) inside the FPGA. There are a fixed number of enemy and bullet "slots". See [enemies.vhd](bonuses/proj1/enemies.vhd). This approach caused interactions between these objects (i.e. collision detection) to consume many logic elements (LE's). There must be a separate combinational "collision circuit" for each possible pair of colliding objects. Obviously, this does not scale well. We kept the number of slots small in order to minimize LE use.

A better approach would be to use a single collision circuit and iterate through all possible collision pairs using a FSM, using this single circuit to check for collision and respond appropriately. This would be like a special purpose "collision processor" that could be triggered at the end of each frame. This would take more time per-frame to handle collision but it would significantly reduce LE usage.

# FPGA Resource Usage
<p align="center">
  <img src="img/proj1_res_use.png" width=450>
</p>

# Flashing
You've heard enough and you'd like to play? You'll need:
1. A [DE10-Lite](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=1021) board.
2. A passive [piezo buzzer](https://www.adafruit.com/product/160) connected between IO 12 and GND on the Arduino shield header. (if sound is desired)
3. A VGA cable and monitor.
4. [Quartus Prime Lite](https://fpgasoftware.intel.com/?edition=lite) (Version 20.1 was used) and the USB-Blaster [drivers](https://www.intel.com/content/www/us/en/support/programmable/support-resources/download/dri-usb-blaster-vista.html) installed. Try [disabling](https://www.howtogeek.com/167723/how-to-disable-driver-signature-verification-on-64-bit-windows-8.1-so-that-you-can-install-unsigned-drivers/) driver signature enforcement in Windows 10 if you encounter issues installing the drivers.
5. Lightning-fast reflexes ;)

Inside the [flash](/flash) folder, you'll find the compiled bitstreams suitable for flashing with Quartus. Use the .sof files (SRAM Object Files) for a quick flash that will not persist between power cycles of the board. Use the .pof files (Programmer Object Files) for a more "permanent" flash that will survive a power cycle. Flashing the pof will take longer than the sof.

proj0 is the base game with basic squares as enemies and a white background. proj1 is the "bonus" version with colorful sprites and starfield background.

To Flash:
1. Open Quartus Prime Lite
2. Click Tools->Programmer
3. Click Hardware Setup and select the USB-Blaster, then close
4. Click Add File, select your .pof or .sof
5. For .pof, check the top Program/Configure checkbox
6. Click Start

# Useful Links
https://forum.digikey.com/t/binary-to-bcd-converter-vhdl/12530  
https://forum.digikey.com/t/vga-controller-vhdl/12794  
https://github.com/hildebrandmw/de10lite-hdl  
https://www.nandland.com/goboard/pong-game-in-fpga-with-go-board-vga.html  
https://projectf.io/posts/fpga-graphics/  
https://ece320web.groups.et.byu.net/labs/VGATextGeneration/VGA_Terminal.html  
http://viznut.fi/unscii/  
https://github.com/MadLittleMods/FP-V-GA-Text  
https://seanriddle.com/ripper.html  
https://seanriddle.com/defendersprites.jpg  
https://seanriddle.com/defendersprites.txt  
https://ezgif.com/  
