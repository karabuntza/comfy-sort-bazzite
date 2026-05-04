#!/bin/bash
VERSION="5.7-ghost-hunter"
API_KEY="13b8f7967e886328b2640edaeb70ca2b"
CONTAINER_NAME="comfy-space"

# Пути
COMFY_ROOT="/var/mnt/09a5645e-a291-438b-bced-bef6edf0d693/ComfyUI"
INPUT_DIR="$COMFY_ROOT/INPUT"
LORA_DIR="$COMFY_ROOT/models/loras"

echo "------------------------------------------------"
echo "🚀 ComfySort v$VERSION"

if [ ! -d "$INPUT_DIR" ]; then
    echo "❌ ПАПКА НЕ НАЙДЕНА: $INPUT_DIR"
    exit 1
fi

# Проверка наличия любых файлов для отладки
echo "📂 Проверка содержимого INPUT..."
ls "$INPUT_DIR" | head -n 5

if [ "$(podman inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" != "true" ]; then
    podman start $CONTAINER_NAME && sleep 2
fi

# Используем find с ключом -iname (регистронезависимо)
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

    if mv "$file" "$LORA_DIR/${prefix}${filename}"; then
        echo "✅ -> $prefix"
    else
        echo "❌ Ошибка переноса"
    fi
done

cd ~/scripts/comfy-sort && git add . && git commit -m "v$VERSION" --quiet && git push origin main --quiet
