# JustDanceClone

### Week 1 of "An App A Week" Challenge - Just Dance game for iOS! 

Record the dance you want to dance along to, then dance to the same dance for the app to rate it!


### Goals:

To learn more about CoreML, CoreMedia in a hands-on project that I've been meaning to attempt for a while 


### Technical write-up 

This app was built on-top of tucan9389's PoseEstimation-CoreML repo, that uses Apple's Pose Estmation for iOS with CoreML to get the body-pose estimations

<img src="https://github.com/JohnBaer3/JustDanceClone/blob/main/IMG_6954.png" width="200" height="400">

1. In the initial screen, I am getting the xy coordinates that the model estimates are the likely locations for each of the body parts, in real time. This is done by running each captured frame from the camera through the CoreML framework, and rendering the points + lines on a View ontop of the video preview layer. 

<img src="https://github.com/JohnBaer3/JustDanceClone/blob/main/IMG_6955.png" width="200" height="400">

2. Once the user clicks "record", I start storing the predicted xy coordinates + time captured into a [Float:[Int:[(CGFloat, CGFloat)?]]] Dictionary, where the reference is in the order of time:[number related to a body point:[(x y coordinate)]]. I capture a new frame and put it into the dictionary every 1/10 seconds, and is done until the user stops recording, or 20 seconds passes for memory and performance issues. 

<img src="https://github.com/JohnBaer3/JustDanceClone/blob/main/IMG_6956.png" width="200" height="400">

3. The second screen starts off with a "Start" button and a 3 second timer for the user to position themselves in frame. Thereafter the screen starts comparing the user's current dance to the previous, recorded dance. To account for body-part's xy coordinates being compared not being a good predictor(a case where someone might be dancing perfectly, but be recording themselves 100px lower on the screen, giving them a terrible score would be very likely), I calculated the dance's score based on angle between each of the body-parts. To expand on this, if a user's right-arm and right-wrist is calculated to be at a 90* angle, and the same for the recorded dance, we can conclude that they are both in the same relative motion for a given timeframe. The accuracy of the dance for each 1/10 second is calculated as: 1-(difference in angle for each of the body parts / 360 / 13), with slight modifiers for body-parts that are predicted poorly (wrists tended to to not be predicted well with fast movements). 

3.5 Every 5 seconds, when the score is > 85% for the previous 3 seconds a "Great!" indicator pops up for the user. For > 60% I give a "Good!" indicator, otherwise an "Ok" indicator pops up. 

<img src="https://github.com/JohnBaer3/JustDanceClone/blob/main/IMG_6957.png" width="200" height="400">

4. The results are tallied up and displayed on the final screen. 

## App in action:
https://vimeo.com/504189098
