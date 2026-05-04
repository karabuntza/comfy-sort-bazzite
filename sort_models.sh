#!/bin/bash
VERSION="4.5-translocator"
API_KEY="13b8f7967e886328b2640edaeb70ca2b"
CONTAINER_NAME="comfy-space"
COMFY_ROOT="/home/user/ComfyUI"

echo "------------------------------------------------"
echo "🚀 ComfySort Script v$VERSION"
echo "🛡️ Проверка контейнера и INPUT папки..."

# ПРОВЕРКА КОНТЕЙНЕРА
if [ "$(podman inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" != "true" ]; then
    podman start $CONTAINER_NAME && sleep 3
fi

podman exec -u root -it $CONTAINER_NAME bash -c "
apt-get update -qq && apt-get install -y -qq curl jq > /dev/null

# Список папок для сканирования: основная models и заблудшая input
SEARCH_PATHS=\"$COMFY_ROOT/models $COMFY_ROOT/input\"
TARGET_LORA_DIR=\"$COMFY_ROOT/models/loras\"

find \$SEARCH_PATHS -type f \( -iname '*.safetensors' -o -iname '*.ckpt' \) \
! -name 'PONY_*' ! -name 'SDXL_*' ! -name 'SD15_*' ! -name 'ILLUST_*' ! -name 'FLUX_*' ! -name 'SD_*' \
! -path '*/clip/*' ! -path '*/vae/*' ! -path '*/controlnet/*' | while read -r file; do
    
    filename=\$(basename \"\$file\")
    current_dir=\$(dirname \"\$file\")
    prefix=\"\"
    
    # 1. Ручные исключения (Bikabaka)
    if [[ \"\$filename\" == *\"bikabaka\"* ]]; then
        prefix=\"PONY_\"
    fi

    # 2. Поиск по API Civitai
    if [[ -z \"\$prefix\" ]]; then
        hash=\$(sha256sum \"\$file\" | cut -d ' ' -f 1)
        res=\$(curl -s -L -H \"Authorization: Bearer $API_KEY\" \"https://civitai.com/api/v1/model-versions/by-hash/\$hash\")
        if [[ -n \"\$res\" && \"\$res\" == *\"baseModel\"* ]]; then
            base=\$(echo \"\$res\" | jq -r '.baseModel' | tr '[:upper:]' '[:lower:]')
            [[ \"\$base\" == *\"pony\"* ]] && prefix=\"PONY_\"
            [[ \"\$base\" == *\"illustrious\"* ]] && prefix=\"ILLUST_\"
            [[ \"\$base\" == *\"flux\"* ]] && prefix=\"FLUX_\"
            [[ \"\$base\" == *\"sdxl\"* ]] && prefix=\"SDXL_\"
            [[ -z \"\$prefix\" ]] && prefix=\"SD_\"
        fi
    fi

    if [[ -n \"\$prefix\" ]]; then
        # Если файл в папке INPUT — переносим его в loras
        if [[ \"\$current_dir\" == *\"/input\"* ]]; then
            mv \"\$file\" \"\$TARGET_LORA_DIR/\${prefix}\${filename}\"
            echo \"📦 ПЕРЕНЕСЕНО ИЗ INPUT: \$filename -> \$prefix\"
        else
            mv \"\$file\" \"\$current_dir/\${prefix}\${filename}\"
            echo \"✅ ПЕРЕИМЕНОВАНО: \$filename -> \$prefix\"
        fi
    fi
done
"

# СИНХРОНИЗАЦИЯ С GITHUB
cd ~/scripts/comfy-sort
git add sort_models.sh
git commit -m "Update to v$VERSION (Scan Input folder)" --quiet
git push origin main --quiet && echo "☁️ GitHub обновлен до v$VERSION"
