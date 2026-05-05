#!/bin/bash

# Escrito por Rodrigo Esteves baitsart@gmail.com www.youtube.com/user/baitsart 
# Licencia GNU. Eres libre de modificar y redistribuir   # 

web_host=$(echo `ping -c 1 www.google.com`)
if [ -z "$web_host" ] ; then
	notify-send "No hay internet"
exit
fi
lang="es"
if [ -n "$1" ]; then
lang=$( echo "$1" | uniq )
echo "Idioma `cat ~/.voice_commands/Scripts/languages | sed 's/), (/\n/g;s/(//g;s/)//g' | grep "$lang " | cut -d' ' -f2 `"
fi
recording=5
key="AIzaSyBOti4mM-6x9WDnZIjIeyEU21OpBXqWBgw"
PROCESS=$$
CMD_RETRY=$(sed -n '111p' ~/.voice_commands/"v-c LANGS"/commands-"$lang" | cut -d "=" -f 2)
microphe_port=$(sed -n '1p' ~/.voice_commands/Scripts/microphone_port | cut -d '=' -f2)
input=$(sed -n '1p' ~/.voice_commands/Scripts/input_port | cut -d '=' -f2)

# Wake word configuration
# Override with the WAKE_WORD environment variable or store in ~/.voice_commands/Scripts/wake_word
if [ -z "$WAKE_WORD" ] && [ -f ~/.voice_commands/Scripts/wake_word ]; then
  WAKE_WORD=$(head -1 ~/.voice_commands/Scripts/wake_word | xargs)
fi
: "${WAKE_WORD:=Hey Zorin}"
WAKE_WORD_LOWER=$(echo "$WAKE_WORD" | tr '[:upper:]' '[:lower:]' | xargs)

# Debug/dry-run mode: set VC_DEBUG=1 env var or store "1" in ~/.voice_commands/Scripts/vc_debug
if [ -z "$VC_DEBUG" ] && [ -f ~/.voice_commands/Scripts/vc_debug ]; then
  VC_DEBUG=$(head -1 ~/.voice_commands/Scripts/vc_debug | xargs)
fi
: "${VC_DEBUG:=0}"

if [ -f /tmp/line_of_process ] ; then
PID=$(cat /tmp/process_result)
kill -HUP $PID 2>/dev/null
rm /tmp/line_of_process
> /tmp/result
sh ~/.voice_commands/play_stop.sh
exit
fi

transcribe()
{
echo "
RECONOCIENDO LA VOZ"
notify-send "Probando comando de voz..." "Por favor, espere"

JSON=`curl -s -X POST \
--data-binary @/tmp/voice_"$PID".flac \
--header 'Content-Type: audio/x-flac; rate=16000;' \
'https://www.google.com/speech-api/v2/recognize?output=json&lang='$lang'&key='$key'' | cut -d\" -f8 `
if echo "$JSON" | sed 's/'"'"'/ /g'  | grep -x -q "$CMD_RETRY" ; then
[[ -f /tmp/speech_recognition_prev.tmp ]] || notify-send "No hay un comando anterior" "Córralo de nuevo, por favor"
mv /tmp/speech_recognition_prev.tmp /tmp/speech_recognition.tmp
/bin/bash ~/.voice_commands/speech_commands.sh "$lang"
exit 1
fi
if echo "$JSON" | sed 's/'"'"'/ /g'  | grep -q "Your client does not have permission to get URL" ; then
if new_key=$( zenity --entry --text="La clave de google speech-api/v2, debe ser actualizada.\nPor favor, ingrese una nueva clave correcta.\nDe lo contrario el proceso no se podrá efectuar" --title="speech-api new key"); then
if
curl -s -X POST \
--data-binary @/tmp/voice_"$PID".flac \
--header 'Content-Type: audio/x-flac; rate=16000;' \
'https://www.google.com/speech-api/v2/recognize?output=json&lang='$lang'&key='$new_key'' | grep "Your client does not have permission to get URL" ; then
notify-send "Clave errónea, Mensaje:" "Your client does not have permission to get URL"
exit 0
fi
sed -i 's/'"$key"'/'"$new_key"'/' ~/.voice_commands/play_stop.sh ~/.voice_commands/speech_commands.sh
sh ~/.voice_commands/play_stop.sh
exit 1
fi
exit
fi
UTTERANCE_TEXT=$(echo "$JSON" | sed 's/'"'"'/ /g' | sed '/^$/d' | tr '[:upper:]' '[:lower:]' | xargs)

# Debug/dry-run mode: print recognized text and wake word match result, then exit
if [ "$VC_DEBUG" = "1" ]; then
  echo "[DEBUG] Texto reconhecido: '${UTTERANCE_TEXT}'"
  if [ "$UTTERANCE_TEXT" = "$WAKE_WORD_LOWER" ]; then
    echo "[DEBUG] Palavra de ativação '${WAKE_WORD}': DETECTADA"
  else
    echo "[DEBUG] Palavra de ativação '${WAKE_WORD}': não detectada"
  fi
  rm -f /tmp/voice_"$PID".flac /tmp/result /tmp/vc_wake_word_armed
  killall notify-osd 2>/dev/null
  exit 0
fi

# Wake word gate (2-step recognition)
if [ -f /tmp/vc_wake_word_armed ]; then
  # Second pass: wake word was already accepted — execute the real command
  rm -f /tmp/vc_wake_word_armed
  echo "$UTTERANCE_TEXT" > /tmp/speech_recognition.tmp
  rm /tmp/voice_"$PID".flac
  rm /tmp/result
  killall notify-osd 2>/dev/null
  /bin/bash ~/.voice_commands/speech_commands.sh "$lang"
  rm -f /tmp/process_result /tmp/if_internal_active /tmp/progress_active \
        /tmp/port_errors /tmp/line_of_process
  exit 0
else
  # First pass: check whether the recognized text matches the wake word
  if [ "$UTTERANCE_TEXT" = "$WAKE_WORD_LOWER" ]; then
    touch /tmp/vc_wake_word_armed
    rm -f /tmp/voice_"$PID".flac /tmp/result
    killall notify-osd 2>/dev/null
    notify-send "🎤 ${WAKE_WORD} activado!" "Diga su comando de voz..."
    /bin/bash ~/.voice_commands/play_stop.sh "$lang"
    exit 0
  else
    rm -f /tmp/voice_"$PID".flac /tmp/result
    killall notify-osd 2>/dev/null
    notify-send "Palabra de activación no detectada" "Diga '${WAKE_WORD}' para iniciar"
    exit 0
  fi
fi
}

pre_recog()
{
if [ -f /tmp/result ] ; then
PID=$(cat /tmp/process_result)
killall rec 2>/dev/null
mv /tmp/voice_.flac /tmp/voice_"$PID".flac
killall notify-osd 2>/dev/null
sh /tmp/if_internal_active
transcribe
fi
}
echo "$PROCESS" > /tmp/process_result

pre_recog

 > /tmp/line_of_process


PID=$(cat /tmp/process_result)
killall notify-osd 2>/dev/null
echo "echo -n "'"'"                                "'"'"\\\\r" > /tmp/if_internal_active
ports=$(pacmd list-sources | grep "active port")
if echo "$ports" | grep -q -v "active port: <analog-input-microphone>\|active port: <analog-input-microphone;"; then
v-c -mic "$microphe_port" >/tmp/port_errors
if sed -n '2p' /tmp/port_errors | grep -q -v "La configuración del micrófono, ahora es con este puertos:"; then
cat /tmp/port_errors
rm /tmp/port_errors
rm /tmp/line_of_process
rm /tmp/process_result
rm /tmp/if_internal_active
exit 1
fi
echo "pacmd set-source-port "$microphe_port" '`echo "$ports" | cut -d'>' -f1 | cut -d'<' -f2 `'  >/tmp/port_errors && echo -n "'"'"                                "'"'"\\\\r"  > /tmp/if_internal_active
fi
notify-send "Grabando..." "Hable, por favor" 

echo "echo -n "'"'"  Hable, por favor. Grabando.  "'"'"\\\\r
sleep 0.5 &&
echo -n "'"'"  Hable, por favor. Grabando.. "'"'"\\\\r
sleep 0.5 &&
echo -n "'"'"  Hable, por favor. Grabando..."'"'"\\\\r
sleep 0.5 &&
echo -n "'"'"  Hable, por favor. Grabando.  "'"'"\\\\r
sleep 0.5 &&
echo -n "'"'"  Hable, por favor. Grabando.. "'"'"\\\\r
sleep 0.5 &&
echo -n "'"'"  Hable, por favor. Grabando..."'"'"\\\\r
sleep 0.5 &&
echo -n "'"'"  Hable, por favor. Grabando.  "'"'"\\\\r
sleep 0.5 &&
echo -n "'"'"  Hable, por favor. Grabando.. "'"'"\\\\r
sleep 0.5 &&
echo -n "'"'"  Hable, por favor. Grabando..."'"'"\\\\r
sleep 0.5 &&
echo -n "'"'"  Hable, por favor. Grabando.. "'"'"\\\\r" > /tmp/progress_active
sh /tmp/progress_active &
#paly ~/.voice_commands/sounds/"Grabando. Hable, por favor.mp3"
( rec -q -r 16000 -d /tmp/voice_.flac ) & pid=$!
( sleep "$recording"s && kill -HUP $pid ) 2>/dev/null & watcher=$!
wait $pid 2>/dev/null && pkill -HUP -P $watcher
sh /tmp/if_internal_active
killall notify-osd 2>/dev/null
> /tmp/result
pre_recog

exit 0;

