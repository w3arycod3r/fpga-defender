# fpga-defender
This project was created for Dr. J. W. Bruce's [Digital System Design](http://jwbruce.info/teaching/ece4110/) class at [Tennessee Technological University](https://www.tntech.edu/engineering/programs/ece/).

# Demo

<p align="center">
  <img src="img/demo1.gif" width=450> <img src="img/demo2.gif" width=450>
</p>

[Video with sound](https://www.youtube.com/watch?v=Bie1J2sb7rM)
# Specification
Create a simplified, stylized version of the 1981 arcade classic [*Defender*](https://en.wikipedia.org/wiki/Defender_(1981_video_game)) for the [DE10-Lite](https://www.terasic.com.tw/cgi-bin/page/archive.pl?Language=English&No=1021) MAX 10 FPGA dev board. The video output is 640x480 @ 60 Hz over VGA. The ship is controlled using the on-board accelerometer. Tilting the board from the horizontal will move the ship up, down, left, and right. On-board pushbuttons control game start, pause, and ship fire. Sound effects are played on an attached piezo buzzer. The score is displayed at the top right of the screen, and the current number of lives is shown at the top left. Also, the score and lives are indicated on the 7-segment displays and LEDs on-board.

<p align="center">
  <img src="img/board.jpg" width=450>
</p>

# Gameplay

