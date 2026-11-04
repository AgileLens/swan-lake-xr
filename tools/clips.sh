#!/bin/bash
# Dev diary clips: 1080p30 from Godot's movie writer, then H.264 MP4, raw AVI removed. Private.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GODOT=/opt/homebrew/bin/godot
mkdir -p "$ROOT/clips"
for c in "${@:-regatta finale}"; do
 for clip in $c; do
  AVI="$ROOT/clips/$clip.avi"
  "$GODOT" --xr-mode off --path "$ROOT/project" --resolution 1920x1080 --write-movie "$AVI" --fixed-fps 30 -- --clip=$clip > "$ROOT/out/clip_$clip.log" 2>&1
  ffmpeg -nostdin -y -v error -i "$AVI" -c:v libx264 -pix_fmt yuv420p -crf 20 -preset medium -c:a aac -b:a 160k -movflags +faststart "$ROOT/clips/$clip.mp4" && rm -f "$AVI"
  ffprobe -v error -show_entries format=duration,size:stream=codec_name,width,height,r_frame_rate -of csv=p=0 "$ROOT/clips/$clip.mp4" | tr '\n' ' '; echo
 done
done
