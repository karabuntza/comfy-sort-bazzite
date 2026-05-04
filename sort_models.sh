#!/bin/bash
VERSION="5.5-mountain-king"
API_KEY="13b8f7967e886328b2640edaeb70ca2b"
CONTAINER_NAME="comfy-space"

# Твой реальный путь на другом диске
COMFY_ROOT="/var/mnt/09a5645e-a291-438b-bced-bef6edf0d693/ComfyUI"
EXT_INPUT="$COMFY_ROOT/INPUT"

echo "------------------------------------------------"
echo "🚀 ComfySort Script v$VERSION"
echo "📂 Работаем с диском: $COMFY_ROOT"

# Авто-поиск папки для Лор внутри твоего пути
REAL_LORA_PATH=$(find "$COMFY_ROOT" -maxdepth 3 -type d -name "loras" -o -name "lora" | head -n 1)

if [ -z "$REAL_LORA_PATH" ]; then
    echo "❌ ОШИБКА: Папка для Лор не найдена по пути $COMFY_ROOT"
    exit 1
fi

echo "📍 Папка назначения: $REAL_LORA_PATH"

if [ "$(podman inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" != "true" ]; then
    podman start $CONTAINER_NAME && sleep 3
fi

find "$EXT_INPUT" -maxdepth 1 -type f \( -iname "*.safetensors" -o -iname "*.ckpt" \) | while read -r file; do
    filename=$(basename "$file")
    echo "🔍 Анализ: $filename"

    # Отправляем файл в контейнер для оценки
    prefix=$(podman exec -i $CONTAINER_NAME bash -c "
        hash=\$(sha256sum | cut -d ' ' -f 1)
        res=\$(curl -s -L -H \"Authorization: Bearer $API_KEY\" \"https://civitai.com/api/v1/model-versions/by-hash/\$hash\")
        
        prefix=\"\"
        if [[ \"\$res\" == *\"baseModel\"* ]]; then
            base=\$(echo \"\$res\" | jq -r '.baseModel' | tr '[:upper:]' '[:lower:]')
            [[ \"\$base\" == *\"pony\"* ]] && prefix=\"PONY_\"
            [[ \"\$base\" == *\"illustrious\"* ]] && prefix=\"ILLUST_\"
            [[ \"\$base\" == *\"flux\"* ]] && prefix=\"FLUX_\"
            [[ \"\$base\" == *\"sdxl\"* ]] && prefix=\"SDXL_\"
        fi
        echo \$prefix
    " < "$file")

    [[ "$filename" == *"bikabaka"* ]] && prefix="PONY_"
    [[ -z "$prefix" ]] && prefix="UNKNOWN_"

    if mv "$file" "$REAL_LORA_PATH/${prefix}${filename}"; then
        echo "✅ УСПЕХ: -> $prefix"
    else
        echo "❌ ОШИБКА перемещения"
    fi
done

cd ~/scripts/comfy-sort && git add . && git commit -m "v$VERSION" --quiet && git push origin main --quiet
