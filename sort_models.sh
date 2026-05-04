#!/bin/bash
VERSION="5.0-diamond"
API_KEY="13b8f7967e886328b2640edaeb70ca2b"
CONTAINER_NAME="comfy-space"

echo "------------------------------------------------"
echo "🚀 ComfySort Script v$VERSION"
echo "🛡️ Зачистка папки INPUT..."

if [ "$(podman inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" != "true" ]; then
    podman start $CONTAINER_NAME && sleep 3
fi

# Запускаем процесс внутри контейнера
podman exec -u root -it $CONTAINER_NAME bash -c '
apt-get update -qq && apt-get install -y -qq curl jq > /dev/null

# Прямое сканирование папки INPUT
TARGET="/home/user/ComfyUI/models/loras"
mkdir -p "$TARGET"

find /home/user/ComfyUI/INPUT /home/user/ComfyUI/input -type f \( -iname "*.safetensors" -o -iname "*.ckpt" \) 2>/dev/null | while read -r file; do
    filename=$(basename "$file")
    echo "🔍 Обработка: $filename"
    
    prefix=""
    # 1. Проверка на bikabaka
    if [[ "$filename" == *"bikabaka"* ]]; then
        prefix="PONY_"
    fi

    # 2. Civitai Check
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

    # Если API не ответил, но файл в INPUT - помечаем как UNKNOWN
    [[ -z "$prefix" ]] && prefix="UNKNOWN_"

    mv "$file" "$TARGET/${prefix}${filename}"
    echo "✅ ПЕРЕНЕСЕНО: $filename -> $prefix"
done
'

# Синхронизация с твоим GitHub
cd ~/scripts/comfy-sort && git add . && git commit -m "v$VERSION (Stable)" --quiet && git push origin main --quiet
