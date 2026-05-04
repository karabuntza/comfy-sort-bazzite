#!/bin/bash
VERSION="5.6-absolute-zero"
API_KEY="13b8f7967e886328b2640edaeb70ca2b"
CONTAINER_NAME="comfy-space"

# Жесткие пути
COMFY_ROOT="/var/mnt/09a5645e-a291-438b-bced-bef6edf0d693/ComfyUI"
INPUT_DIR="$COMFY_ROOT/INPUT"
LORA_DIR="$COMFY_ROOT/models/loras"

echo "------------------------------------------------"
echo "🚀 ComfySort v$VERSION"

# Проверка контейнера
if [ "$(podman inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" != "true" ]; then
    podman start $CONTAINER_NAME && sleep 2
fi

# Переходим в папку и работаем напрямую
cd "$INPUT_DIR" || { echo "❌ Не могу войти в $INPUT_DIR"; exit 1; }

for file in *.safetensors *.ckpt; do
    # Если файлов нет, bash выдаст саму строку расширения, проверяем это
    [ -e "$file" ] || continue
    
    echo "🔍 Анализ: $file"
    
    # Считаем хеш и идем в Civitai через контейнер
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

    [[ "$file" == *"bikabaka"* ]] && prefix="PONY_"
    [[ -z "$prefix" ]] && prefix="UNKNOWN_"

    if mv "$file" "$LORA_DIR/${prefix}${file}"; then
        echo "✅ -> $prefix"
    else
        echo "❌ Ошибка при переносе $file"
    fi
done

# GitHub sync
cd ~/scripts/comfy-sort && git add . && git commit -m "v$VERSION" --quiet && git push origin main --quiet
