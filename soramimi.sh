#!/bin/bash
set -eux
if [ $# -ne 1 ]; then
    echo "1 args required"
    exit 1
fi

BASE_DIR=$(cd $(dirname $0); pwd)
OUT_DIR=$BASE_DIR/out
VAD_EXE=$BASE_DIR/vad

MIMI_TOKEN_FILE=token
MIMI_SCRIPT=asr.py

# 入力のフルパス取得
SORAMIMI_TUNE=$1
TUNE_NAME=$(basename "${SORAMIMI_TUNE%.*}")
TUNE_DIR=$(cd $(dirname "${SORAMIMI_TUNE%.*}"); pwd)
TUNE_FULLPATH=$TUNE_DIR/$TUNE_NAME


## Spleeterで楽曲音源分離
if [ ! -e out ]; then
    mkdir -p out
fi
docker run --rm -it -v `pwd`:/work spleeter-model separate -i /work/${SORAMIMI_TUNE} -o /work/out


# ボーカル音源を16kHz RAWに変換
pushd "$OUT_DIR"
WAVE_FILE_NAME="${TUNE_NAME}/vocals.wav"
RAW_FILE_NAME="${TUNE_NAME}/vocals.raw"
sox "$WAVE_FILE_NAME" -e signed -r 16k -b 16 -c 1 "$RAW_FILE_NAME"
popd

# VADでボーカル箇所だけ抜き出し
VAD_DIR=$BASE_DIR/files
if [ ! -e "$VAD_DIR" ]; then
    mkdir -p "$VAD_DIR"
fi

VAD_IN=$OUT_DIR/$RAW_FILE_NAME
$VAD_EXE -i "$VAD_IN"

VAD_OUT=files
VAD_OUT_FILES=$VAD_OUT/$TUNE_NAME
if [ -e "$VAD_OUT_FILES" ]; then
    rm -rf "$VAD_OUT_FILES"
fi
mv $VAD_OUT/$(basename $VAD_IN) $VAD_OUT_FILES

# VADで切り出されたファイルで「日本語の」音声認識をかける
for f in `ls $VAD_OUT_FILES/*.raw`; do
    python $MIMI_SCRIPT $MIMI_TOKEN_FILE $f >> "$VAD_OUT_FILES/out.txt"
done
