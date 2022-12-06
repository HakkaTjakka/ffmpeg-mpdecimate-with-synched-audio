#!/bin/bash

export LC_NUMERIC="en_US.UTF-8"

round() {
  printf "%.${2}f" "${1}"
}

FILENAME=$*
BASENAME="${FILENAME%.*}"

INFO () {
  duration=$( \
    ffprobe -v error \
    -show_entries format=duration \
    -of default=noprint_wrappers=1:nokey=1 \
    "$FILENAME" \
  )
  echo duration=$duration

  frames=$( \
    ffprobe -v error \
      -select_streams v:0 \
      -count_frames \
      -show_entries stream=nb_read_frames \
      -of default=noprint_wrappers=1:nokey=1 \
      "$FILENAME" \
  )
#  frames=146336
  echo frames=$frames
   
  #echo "($frames/$duration)"| bc -l
  FPS=$(echo "($frames/$duration)"| bc -l)
  echo "frames/duration=$FPS"

  FPS=$(ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate "$FILENAME")
  FPS=$(echo "($FPS)"| bc -l)
  echo FPS=$FPS
  frames=$(echo "($FPS*$duration)"| bc -l)
  echo "FPS*duration=$frames"
}


ONE_PIECE () {
  FILENAME=$*
  BASENAME="${FILENAME%.*}"

  FILELENGTH=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FILENAME")
  echo FILELENGTH=$FILELENGTH

  FPS=$(ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate "$FILENAME")
  FPS=$(echo "($FPS)"| bc -l)
  FPS=$(round ${FPS} 3)
  echo FPS=$FPS

  RATE=$(ffprobe -v error -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$FILENAME")
  PITCH="1.00"
  ASETRATE=$(echo "($RATE/$PITCH)"| bc -l)
  ASETRATE=$(round ${ASETRATE} 0)
  echo ASETRATE=$ASETRATE

  ffmpeg -hide_banner \
    -i "$FILENAME" \
    -c:a copy \
    "$BASENAME.AAC"

  ffmpeg -hide_banner \
    -i "$FILENAME" \
    -filter_complex " \
    [0:v]mpdecimate,setpts=N/FRAME_RATE/TB[v] \
    " \
    -map "[v]" \
    -an \
    -vsync vfr \
    -c:v h264_nvenc -pix_fmt yuv420p -preset fast -b:v 25M \
    -c:a aac -ac 2 -b:a 64k \
    "$BASENAME.DECIMATED2.MP4"

  echo FILELENGTH1=$FILELENGTH
  FILELENGTH2=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$BASENAME.DECIMATED2.MP4")
  echo FILELENGTH2=$FILELENGTH2

  SPEED=$(echo "(1.0/(($FILELENGTH/$FILELENGTH2)/$PITCH))"| bc -l)
  SPEED=$(round ${SPEED} 4)
  echo SPEED=$SPEED

  ATEMPO=$(echo "(1.0/($SPEED/$PITCH))"| bc -l)
  ATEMPO=$(round ${ATEMPO} 4)
  echo ATEMPO=$ATEMPO

  ffmpeg -hide_banner \
    -i "$BASENAME.AAC" \
    -filter_complex " \
    [0:a]asetrate=$RATE/$PITCH,aresample=44100,atempo=($ATEMPO)[a] \
    " \
    -map "[a]" \
    "$BASENAME.CUT.AAC"


  #  [0:a]asetrate=$RATE/$PITCH,aresample=44100,atempo=($ATEMPO)[a] \
  FILELENGTH3=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$BASENAME.CUT.AAC")
  echo FILELENGTH3=$FILELENGTH3

  ffmpeg -hide_banner \
    -i "$BASENAME.CUT.AAC" \
    -i "$BASENAME.DECIMATED2.MP4" \
    -c:v h264_nvenc -pix_fmt yuv420p -preset fast -b:v 10M \
    -c:a copy $BASENAME.FIXED.MP4
  #  -c:a aac -ac 2 -b:a 64k \

}

ffmpeg -hide_banner \
 -i "$FILENAME" \
 -c copy -map 0 -segment_time 00:00:30 -f segment -reset_timestamps 1 "party%03d.mp4"

rm filelist.txt
for line in party*.mp4
do
 BASENAME="${line%.*}"
 echo "file '$BASENAME.FIXED.MP4'" >> filelist.txt
 ONE_PIECE "$line"
done

#ffmpeg -safe 0 -f concat -i filelist.txt -c copy complete.mp4

ffmpeg -safe 0 -f concat -i filelist.txt -c:v h264_nvenc -pix_fmt yuv420p -preset fast -b:v 10M complete.mp4
#cat filelist.txt

exit

#######################################




DOSOME1 () {
  FILENAME="$*"
  BASENAME="${FILENAME%.*}"

  FILELENGTH=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FILENAME")

  FPS=$(ffprobe -v 0 -of csv=p=0 -select_streams v:0 -show_entries stream=r_frame_rate "$FILENAME")
  FPS=$(echo "($FPS)"| bc -l)

  PITCH="1.00"
  SPEED=0.5
  ATEMPO=$(echo "(1.0/($SPEED/$PITCH))"| bc -l)
  ATEMPO=$(round ${ATEMPO} 3)

  RATE=$(ffprobe -v error -show_entries stream=sample_rate -of default=noprint_wrappers=1:nokey=1 "$FILENAME")
  ASETRATE=$(echo "($RATE/$PITCH)"| bc -l)
  ASETRATE=$(round ${ASETRATE} 0)

#  FPS=$(round ${FPS} 2)
  FPS2="60"
#  FPS2=$(echo "(($FPS*2))"| bc -l)
#  FPS=$(echo "(1.0/($SPEED/$PITCH))"| bc -l)

  echo ASETRATE     =$ASETRATE
  echo ATEMPO       =$ATEMPO
  echo FPS          =$FPS
  echo FILELENGTH   =$FILELENGTH
  echo FPS2         =$FPS2
  #exit

    ffmpeg -hide_banner \
      -i "$FILENAME" \
      -filter_complex " \
      [0:v]setpts=$SPEED*PTS,fps=fps=$FPS2[v]; \
      [0:a]asetrate=$ASETRATE,aresample=44100,atempo=$ATEMPO[a] \
      " \
      -vsync vfr \
      -map "[v]" -map "[a]" \
      -c:v h264_nvenc -pix_fmt yuv420p -preset slow -b:v 10M \
      -c:a aac -ac 2 -b:a 64k \
      "$BASENAME.X2.MP4"

#  FILENAME="$BASENAME.TWITTER.DECIMATED3.MP4"
#  INFO
}



### ffmpeg -i "$FILENAME" input.mp4 -c copy -map 0 -segment_time 00:20:00 -f segment output%03d.mp4
#-segment_time 00:20:00 -f segment -reset_timestamps 1



####        [0:a]asetrate=$ASETRATE,aresample=44100,atempo=$ATEMPO[a] \
#### 
####   frames=$( \
####     ffprobe -v error \
####       -select_streams v:0 \
####       -count_frames \
####       -show_entries stream=nb_read_frames \
####       -of default=noprint_wrappers=1:nokey=1 \
####       "$FILENAME" \
####   )
####   echo frames in= $frames
#### 
####   frames2=$( \
####     ffprobe -v error \
####       -select_streams v:0 \
####       -count_frames \
####       -show_entries stream=nb_read_frames \
####       -of default=noprint_wrappers=1:nokey=1 \
####       "$BASENAME.DECIMATED2.MKV" \
####   )
####   echo frames out=$frames2
#### 
#### 
#### SPEED=$(echo "(1.0/(($frames2/$frames)/$PITCH))"| bc -l)
#### echo SPEED=$SPEED
#### 
#### ATEMPO=$(echo "(1.0/($SPEED/$PITCH))"| bc -l)
#### ATEMPO=$(round ${ATEMPO} 4)
#### 
#### echo ATEMPO=$ATEMPO
#### 

### SPEED=0.25
### ATEMPO=$(echo "(1.0/($SPEED/$PITCH))"| bc -l)
### ATEMPO=$(round ${ATEMPO} 2)
### 
### echo ATEMPO=$ATEMPO

## ffmpeg -hide_banner \
##   -i "$FILENAME" \
##   -c:v copy \
##   -an \
##   "$BASENAME.TWITTER.MKV"

#  -c:v h264_nvenc -pix_fmt yuv420p -preset fast -b:v 6000k \


## FILELENGTH=$(ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$FILENAME")
## 
## ffmpeg -hide_banner -y -i ra.aac -ss 00:00:00 -t $FILELENGTH cut.aac
## 
## ffmpeg -hide_banner -y \
##   -i cut.aac \
##   -i "$FILENAME" \
##   -filter_complex "[0:a][1:a]amix=inputs=2[a]" \
##   -map "[a]" \
##   -map 1:v \
##   -c:v copy result.mp4
## #ffmpeg -i $FILENAME -i ra.aac -c copy -shortest $BASENAME.mixed.mp4
## exit


# DOSOME1 "complete.mp4"

###   ffmpeg -hide_banner \
###     -i "$FILENAME" \
###     -filter_complex "aresample=44100" \
###     -c:v h264_nvenc -pix_fmt yuv420p -preset slow \
###     "$BASENAME.SMALL.MP4"
