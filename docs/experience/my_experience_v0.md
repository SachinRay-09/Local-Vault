PC-
flutter: [Benchmark] Total unlock: 14574ms

Put the password and took 5 sec or more for the first time opening the new upgraded version.
Second time ran the debugg app window and put the password and it was decently quicker than 1st try, around 2 sec or less.
Then When changed the this.formatVersion to 1, it still took some time. (it's okay if it taskes this much time)

1. imported a folder with around 8 picture and import was fast.
-though one issue that I noticed was when I traversed from 1st image to last it was good, smoothly moving to next image. Issue was when I reached last image and pressed previous button, there was slight black screen in place of image and after few milli seconds the previous picture appeared, and when I pressed next the same thing happned. So it was clear that something is wrong with previous button. !st iteration of moving from first to last image and amazing and good(this is how I was it) but going to previous images or going to next image after pressing previous button resulting in a black screen appearing in place of image of few ms which looks bad so try to fix this, pin point exact issue why this is happening and look on internet for solution for such issues.
- the above solution wasn't a issue in phone(virtual device) once I opened the image and moved next, and then moved previous it was working fine no black screen like in pc version.

Importing 8 image folder is very fast on my pc and the natural sorting is working correctly like we want 1,2,3,...,10,11 and so. 

Another this I noticed is complete removal of password protected export, I may say this is good choice cause the password protected zip was a nightmare to extract on my phone due to low ram capacity. Though I need some clarification about why removed it and if we can implement it in future.

When I changed this.formatVersion to 1, and I imported the same 8 image folder and it took more, like lot more that it took with this.formatVersion = 0(as I have mentioned above, it was quick). Similarly when exporting it took more time and even when openeing an image after import it took little more for loading image. 
- Why is this? wasn't it supposed to increase the speed 5-8x. Check on internet- projects, system designs for reliable evidence on why it made the import export slow and what's going wrong.
And should we continue to go with this.formatVersion = 0.


Android-
Creating a new vault did took some time and similarly putting password took time but importing 8 image zip from the pc version was decentlt fast, took 2-4 seconds for both files. Though there were not as such stutters (feels same as old app) through the actual app performance will be checked when I will import a zip of around 1 or 2 gb or more at once.
I want you to simulate this situaltion answer how much time it would take, how it will import 2 gb zip with 100s of images on my phone(6gb ram), the work flow and how much time is estimated as t best based on real life scenarios. 