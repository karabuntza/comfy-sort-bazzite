#!/bin/bash
VERSION="4.9-omni-scan"
API_KEY="13b8f7967e886328b2640edaeb70ca2b"
CONTAINER_NAME="comfy-space"

echo "------------------------------------------------"
echo "🚀 ComfySort Script v$VERSION"
echo "🛡️ Поиск путей и зачистка..."

if [ "$(podman inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" != "true" ]; then
    podman start $CONTAINER_NAME && sleep 3
fi

podman exec -u root -it $CONTAINER_NAME bash -c '
# Находим, где реально лежит ComfyUI внутри контейнера
REAL_ROOT=$(find / -maxdepth 3 -name "models" -type d -path "*ComfyUI*" | head -n 1 | sed "s/\/models//")

if [ -z "$REAL_ROOT" ]; then
    # Если не нашли по models, пробуем стандартные пути
    [[ -d "/home/user/ComfyUI" ]] && REAL_ROOT="/home/user/ComfyUI"
    [[ -d "/workspace/ComfyUI" ]] && REAL_ROOT="/workspace/ComfyUI"
fi

echo "📍 Корень ComfyUI найден в: $REAL_ROOT"

SEARCH_PATHS="$REAL_ROOT/models $REAL_ROOT/input $REAL_ROOT/INPUT"
TARGET_LORA_DIR="$REAL_ROOT/models/loras"

# Создаем папку loras, если её нет
mkdir -p "$TARGET_LORA_DIR"

find $SEARCH_PATHS -type f \( -iname "*.safetensors" -o -iname "*.ckpt" \) \
! -path "*/clip/*" ! -path "*/vae/*" ! -path "*/controlnet/*" 2>/dev/null | while read -r file; do
    
    filename=$(basename "$file")
    current_dir=$(dirname "$file")
    
    # Пропускаем уже готовые
    [[ "$filename" =~ ^(PONY_|SDXL_|SD15_|ILLUST_|FLUX_|SD_|UNKNOWN_) ]] && continue

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
            [[ -z "$prefix" ]] && prefix="SD_"
        fi
    fi

    # Если это в INPUT и Civitai не ответил
    if [[ -z "$prefix" && ( "$current_dir" == *"/input"* || "$current_dir" == *"/INPUT"* ) ]]; then
        prefix="UNKNOWN_"
    fi

    if [[ -n "$prefix" ]]; then
        mv "$file" "$TARGET_LORA_DIR/${prefix}${filename}"
        echo "📦 ПЕРЕНЕСЕНО: $filename -> $prefix"
    fi
done
'

# GitHub sync
cd ~/scripts/comfy-sort && git add . && git commit -m "v$VERSION" --quiet && git push origin main --quiet
