#!/bin/bash
VERSION="4.8-path-fixed"
API_KEY="13b8f7967e886328b2640edaeb70ca2b"
CONTAINER_NAME="comfy-space"
COMFY_ROOT="/home/user/ComfyUI"

echo "------------------------------------------------"
echo "🚀 ComfySort Script v$VERSION"
echo "🛡️ Зачистка папки INPUT (Fixing Paths)..."

if [ "$(podman inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" != "true" ]; then
    podman start $CONTAINER_NAME && sleep 3
fi

# Используем одинарные кавычки для EOF, чтобы Bash не трогал переменные внутри
podman exec -u root -it $CONTAINER_NAME bash -c '
apt-get update -qq && apt-get install -y -qq curl jq > /dev/null

# Пути теперь жестко прописаны для контейнера
SEARCH_PATHS="/home/user/ComfyUI/models /home/user/ComfyUI/input /home/user/ComfyUI/INPUT"
TARGET_LORA_DIR="/home/user/ComfyUI/models/loras"

find $SEARCH_PATHS -type f \( -iname "*.safetensors" -o -iname "*.ckpt" \) \
! -path "*/clip/*" ! -path "*/vae/*" ! -path "*/controlnet/*" 2>/dev/null | while read -r file; do
    
    filename=$(basename "$file")
    current_dir=$(dirname "$file")
    prefix=""
    
    [[ "$filename" =~ ^(PONY_|SDXL_|SD15_|ILLUST_|FLUX_|SD_|UNKNOWN_) ]] && continue

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

    if [[ -z "$prefix" && ( "$current_dir" == *"/input"* || "$current_dir" == *"/INPUT"* ) ]]; then
        prefix="UNKNOWN_"
    fi

    if [[ -n "$prefix" ]]; then
        if [[ "$current_dir" == *"/input"* || "$current_dir" == *"/INPUT"* ]]; then
            mv "$file" "$TARGET_LORA_DIR/${prefix}${filename}"
            echo "📦 ПЕРЕНЕСЕНО: $filename -> $prefix"
        else
            mv "$file" "$current_dir/${prefix}${filename}"
            echo "✅ ПЕРЕИМЕНОВАНО: $filename -> $prefix"
        fi
    fi
done
'

# GitHub sync
cd ~/scripts/comfy-sort && git add . && git commit -m "v$VERSION (Path fix)" --quiet && git push origin main --quiet
