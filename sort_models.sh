#!/bin/bash
VERSION="5.1-total-scanner"
API_KEY="13b8f7967e886328b2640edaeb70ca2b"
CONTAINER_NAME="comfy-space"

echo "------------------------------------------------"
echo "🚀 ComfySort Script v$VERSION"
echo "🛡️ Ищем папку INPUT внутри контейнера..."

if [ "$(podman inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" != "true" ]; then
    podman start $CONTAINER_NAME && sleep 3
fi

podman exec -u root -it $CONTAINER_NAME bash -c '
# 1. Находим ГДЕ ВООБЩЕ лежит ComfyUI
ROOT=$(find / -maxdepth 4 -name "models" -type d | grep ComfyUI | head -n 1 | sed "s/\/models//")
if [ -z "$ROOT" ]; then ROOT="/home/user/ComfyUI"; fi

# 2. Ищем папку INPUT (любым регистром)
IN_PATH=$(find "$ROOT" -maxdepth 2 -type d -iname "input" | head -n 1)
LORA_PATH="$ROOT/models/loras"

echo "📍 Нашел вход: $IN_PATH"
echo "📍 Нашел выход: $LORA_PATH"

# 3. Обработка файлов
find "$IN_PATH" -maxdepth 2 -type f \( -iname "*.safetensors" -o -iname "*.ckpt" \) | while read -r file; do
    filename=$(basename "$file")
    echo "🔍 Нашел файл: $filename"
    
    prefix=""
    if [[ "$filename" == *"bikabaka"* ]]; then
        prefix="PONY_"
    fi

    if [[ -z "$prefix" ]]; then
        hash=$(sha256sum "$file" | cut -d " " -f 1)
        res=$(curl -s -L -H "Authorization: Bearer 13b8f7967e886328b2640edaeb70ca2b" "https://civitai.com/api/v1/model-versions/by-hash/$hash")
        if [[ -n "$res" && "$res" == *"baseModel"* ]]; then
            base=$(echo "$res" | jq -r ".baseModel" | tr "[:upper:]" "[:lower:]")
            [[ "$base" == *"pony"* ]] && prefix="PONY_"
            [[ "$base" == *"illustrious"* ]] && prefix="ILLUST_"
            [[ "$base" == *"flux"* ]] && prefix="FLUX_"
            [[ "$base" == *"sdxl"* ]] && prefix="SDXL_"
        fi
    fi

    [[ -z "$prefix" ]] && prefix="UNKNOWN_"
    
    mv "$file" "$LORA_PATH/${prefix}${filename}"
    echo "✅ ПЕРЕНЕСЕНО: $filename -> $prefix"
done
'

cd ~/scripts/comfy-sort && git add . && git commit -m "v$VERSION" --quiet && git push origin main --quiet
