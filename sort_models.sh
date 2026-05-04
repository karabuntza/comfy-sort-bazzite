#!/bin/bash
VERSION="4.2-dark-urge"

# --- НАСТРОЙКИ ---
API_KEY="13b8f7967e886328b2640edaeb70ca2b"
CONTAINER_NAME="comfy-space"
COMFY_ROOT="/home/user/ComfyUI"

echo "------------------------------------------------"
echo "🚀 ComfySort Script v$VERSION"
echo "🛡️ Режим: Доблесть (Хеш + API + Имя)"
echo "------------------------------------------------"

podman exec -u root -it $CONTAINER_NAME bash -c "
apt-get update -qq && apt-get install -y -qq curl jq > /dev/null

find $COMFY_ROOT/models -type f \( -iname '*.safetensors' -o -iname '*.ckpt' \) \
! -name 'PONY_*' ! -name 'SDXL_*' ! -name 'SD15_*' ! -name 'ILLUST_*' ! -name 'FLUX_*' ! -name 'SD_*' \
! -path '*/clip/*' ! -path '*/vae/*' ! -path '*/controlnet/*' | while read -r file; do
    
    filename=\$(basename \"\$file\")
    dir=\$(dirname \"\$file\")
    search_query=\$(echo \"\$filename\" | sed 's/\.[^.]*$//; s/[-_]0000[0-9]*//g; s/(.*)//g')
    
    echo -n \"🔍 Анализ \$filename... \"
    prefix=\"\"
    
    # [Логика поиска остается прежней, но теперь стабильнее]
    hash=\$(sha256sum \"\$file\" | cut -d ' ' -f 1)
    res_h=\$(curl -s -L -H \"Authorization: Bearer $API_KEY\" --connect-timeout 10 \"https://civitai.com/api/v1/model-versions/by-hash/\$hash\")
    
    if [[ -n \"\$res_h\" && \"\$res_h\" == *\"baseModel\"* ]]; then
        base=\$(echo \"\$res_h\" | jq -r '.baseModel' | tr '[:upper:]' '[:lower:]')
        [[ \"\$base\" == *\"pony\"* ]] && prefix=\"PONY_\"
        [[ \"\$base\" == *\"illustrious\"* ]] && prefix=\"ILLUST_\"
        [[ \"\$base\" == *\"flux\"* ]] && prefix=\"FLUX_\"
        [[ \"\$base\" == *\"sdxl\"* ]] && prefix=\"SDXL_\"
        [[ -z \"\$prefix\" ]] && prefix=\"SD_\"
    fi

    if [[ -z \"\$prefix\" ]]; then
        low_name=\$(echo \"\$filename\" | tr '[:upper:]' '[:lower:]')
        if [[ \"\$low_name\" == *\"pony\"* ]]; then prefix=\"PONY_\"
        elif [[ \"\$low_name\" == *\"illustrious\"* || \"\$low_name\" == *\"illus\"* ]]; then prefix=\"ILLUST_\"
        elif [[ \"\$low_name\" == *\"flux\"* ]]; then prefix=\"FLUX_\"
        elif [[ \"\$low_name\" == *\"sdxl\"* || \"\$low_name\" == *\"xl\"* ]]; then prefix=\"SDXL_\"
        fi
    fi

    if [[ -n \"\$prefix\" ]]; then
        mv \"\$file\" \"\$dir/\${prefix}\${filename}\"
        echo \"✅ \$prefix\"
    else
        echo \"⚠️ Не узнал\"
    fi
done
"
