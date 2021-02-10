# JustDanceClone

### Week 1 of "An App A Week" Challenge. 

## Just Dance game for iOS! 

Record the dance you want to dance along to, then dance to the same dance for the app to rate it!

### Goals:

To learn more about CoreML, CoreMedia in a hands-on project that I've been meaning to attempt for a while 

## Technical write-up 

This app was built on-top of tucan9389's PoseEstimation-CoreML repo, that uses Apple's Pose Estmation for iOS with CoreML to get the body-pose estimations

1. <img src="https://github.com/JohnBaer3/JustDanceClone/blob/main/IMG_6954.png" width="200" height="400">




In the initial screen, I am grabbing estimations from the front-facing camera. Once the user clicks "start", the app begins to record each of the predictions every 1/10 seconds, and builds a Dictionary that matches each of the 1/10 seconds to a Dictionary of the body-point estimations. The body-point estimations are stored in a form of 'angle from current body-part to adjacent body-part'. 

This is important, as angle between body-parts is a more accurate predictor 

### App in action:
https://vimeo.com/504189098
