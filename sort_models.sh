#!/bin/bash
VERSION="4.7-input-overdrive"
API_KEY="13b8f7967e886328b2640edaeb70ca2b"
CONTAINER_NAME="comfy-space"
COMFY_ROOT="/home/user/ComfyUI"

echo "------------------------------------------------"
echo "🚀 ComfySort Script v$VERSION"
echo "🛡️ Зачистка папки INPUT (регистронезависимо)..."

if [ "$(podman inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" != "true" ]; then
    podman start $CONTAINER_NAME && sleep 3
fi

podman exec -u root -it $CONTAINER_NAME bash -c "
apt-get update -qq && apt-get install -y -qq curl jq > /dev/null

# Явно ищем и в input, и в INPUT
SEARCH_PATHS=\"\$COMFY_ROOT/models \$COMFY_ROOT/input \$COMFY_ROOT/INPUT\"
TARGET_LORA_DIR=\"\$COMFY_ROOT/models/loras\"

find \$SEARCH_PATHS -type f \( -iname '*.safetensors' -o -iname '*.ckpt' \) \
! -path '*/clip/*' ! -path '*/vae/*' ! -path '*/controlnet/*' | while read -r file; do
    
    filename=\$(basename \"\$file\")
    current_dir=\$(dirname \"\$file\")
    prefix=\"\"
    
    # Пропускаем уже готовые
    [[ \"\$filename\" =~ ^(PONY_|SDXL_|SD15_|ILLUST_|FLUX_|SD_|UNKNOWN_) ]] && continue

    # 1. Ручные исключения
    if [[ \"\$filename\" == *\"bikabaka\"* ]]; then
        prefix=\"PONY_\"
    fi

    # 2. Civitai API
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

    # 3. Если это в папке INPUT/input и префикс так и не найден
    if [[ -z \"\$prefix\" && ( \"\$current_dir\" == *\"/input\"* || \"\$current_dir\" == *\"/INPUT\"* ) ]]; then
        prefix=\"UNKNOWN_\"
    fi

    if [[ -n \"\$prefix\" ]]; then
        # Если файл из любого варианта input — ПЕРЕНОСИМ
        if [[ \"\$current_dir\" == *\"/input\"* || \"\$current_dir\" == *\"/INPUT\"* ]]; then
            mv \"\$file\" \"\$TARGET_LORA_DIR/\${prefix}\${filename}\"
            echo \"📦 ПЕРЕНЕСЕНО: \$filename -> \$prefix\"
        else
            mv \"\$file\" \"\$current_dir/\${prefix}\${filename}\"
            echo \"✅ ПЕРЕИМЕНОВАНО: \$filename -> \$prefix\"
        fi
    fi
done
"

# GitHub sync
cd ~/scripts/comfy-sort && git add . && git commit -m "v$VERSION (Fix INPUT casing)" --quiet && git push origin main --quiet
