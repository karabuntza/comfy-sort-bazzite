#!/bin/bash
VERSION="5.8-the-finder"
API_KEY="13b8f7967e886328b2640edaeb70ca2b"
CONTAINER_NAME="comfy-space"

# Список возможных путей (проверим оба)
PATHS=("/var/home/junme/ComfyUI" "/var/mnt/09a5645e-a291-438b-bced-bef6edf0d693/ComfyUI")

FOUND_ROOT=""
for p in "${PATHS[@]}"; do
    if [ -d "$p/INPUT" ] && [ "$(ls -A "$p/INPUT" 2>/dev/null)" ]; then
        FOUND_ROOT="$p"
        echo "✅ Файлы найдены в: $FOUND_ROOT/INPUT"
        break
    fi
done

if [ -z "$FOUND_ROOT" ]; then
    echo "❌ ОШИБКА: Ни в одной папке INPUT файлов не найдено."
    echo "Проверь вручную, где лежат твои .safetensors"
    exit 1
fi

INPUT_DIR="$FOUND_ROOT/INPUT"
# Ищем папку loras динамически
LORA_DIR=$(find "$FOUND_ROOT" -type d -name "loras" -o -name "lora" | head -n 1)

if [ -z "$LORA_DIR" ]; then
    LORA_DIR="$FOUND_ROOT/models/loras"
    mkdir -p "$LORA_DIR"
fi

echo "📍 Цель: $LORA_DIR"

if [ "$(podman inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" != "true" ]; then
    podman start $CONTAINER_NAME && sleep 2
fi

find "$INPUT_DIR" -maxdepth 1 -type f \( -iname "*.safetensors" -o -iname "*.ckpt" \) | while read -r file; do
    filename=$(basename "$file")
    echo "🔍 Анализ: $filename"
    
    prefix=$(podman exec -i $CONTAINER_NAME bash -c "
        hash=\$(sha256sum | cut -d ' ' -f 1)
        res=\$(curl -s -L -H \"Authorization: Bearer $API_KEY\" \"https://civitai.com/api/v1/model-versions/by-hash/\$hash\")
        if [[ \"\$res\" == *\"baseModel\"* ]]; then
            base=\$(echo \"\$res\" | jq -r '.baseModel' | tr '[:upper:]' '[:lower:]')
            [[ \"\$base\" == *\"pony\"* ]] && echo \"PONY_\" && exit
            [[ \"\$base\" == *\"illustrious\"* ]] && echo \"ILLUST_\" && exit
            [[ \"\$base\" == *\"flux\"* ]] && echo \"FLUX_\" && exit
            [[ \"\$base\" == *\"sdxl\"* ]] && echo \"SDXL_\" && exit
            echo \"SD_\"
        fi
    " < "$file")

    [[ "$filename" == *"bikabaka"* ]] && prefix="PONY_"
    [[ -z "$prefix" ]] && prefix="UNKNOWN_"

    mv "$file" "$LORA_DIR/${prefix}${filename}"
    echo "✅ Перемещено в $prefix"
done

cd ~/scripts/comfy-sort && git add . && git commit -m "v$VERSION" --quiet && git push origin main --quiet
