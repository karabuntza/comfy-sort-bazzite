#!/bin/bash
VERSION="4.4-auto-revive"
API_KEY="13b8f7967e886328b2640edaeb70ca2b"
CONTAINER_NAME="comfy-space"
COMFY_ROOT="/home/user/ComfyUI"

echo "------------------------------------------------"
echo "🚀 ComfySort Script v$VERSION"
echo "🛡️ Статус контейнера: Проверка..."

# ПРОВЕРКА И ЗАПУСК КОНТЕЙНЕРА
if [ "$(podman inspect -f '{{.State.Running}}' $CONTAINER_NAME 2>/dev/null)" != "true" ]; then
    echo "💤 Контейнер спит. Будим..."
    podman start $CONTAINER_NAME
    sleep 3 # Даем время на инициализацию
fi

podman exec -u root -it $CONTAINER_NAME bash -c "
apt-get update -qq && apt-get install -y -qq curl jq > /dev/null

find $COMFY_ROOT/models -type f \( -iname '*.safetensors' -o -iname '*.ckpt' \) \
! -name 'PONY_*' ! -name 'SDXL_*' ! -name 'SD15_*' ! -name 'ILLUST_*' ! -name 'FLUX_*' ! -name 'SD_*' \
! -path '*/clip/*' ! -path '*/vae/*' ! -path '*/controlnet/*' | while read -r file; do
    
    filename=\$(basename \"\$file\")
    dir=\$(dirname \"\$file\")
    prefix=\"\"
    
    # РУЧНОЕ ИСКЛЮЧЕНИЕ
    if [[ \"\$filename\" == *\"bikabaka\"* ]]; then
        prefix=\"PONY_\"
    fi

    if [[ -z \"\$prefix\" ]]; then
        hash=\$(sha256sum \"\$file\" | cut -d ' ' -f 1)
        res=\$(curl -s -L -H \"Authorization: Bearer $API_KEY\" \"https://civitai.com/api/v1/model-versions/by-hash/\$hash\")
        if [[ -n \"\$res\" && \"\$res\" == *\"baseModel\"* ]]; then
            base=\$(echo \"\$res\" | jq -r '.baseModel' | tr '[:upper:]' '[:lower:]')
            [[ \"\$base\" == *\"pony\"* ]] && prefix=\"PONY_\"
            [[ \"\$base\" == *\"illustrious\"* ]] && prefix=\"ILLUST_\"
            [[ \"\$base\" == *\"flux\"* ]] && prefix=\"FLUX_\"
            [[ \"\$base\" == *\"sdxl\"* ]] && prefix=\"SDXL_\"
        fi
    fi

    if [[ -n \"\$prefix\" ]]; then
        mv \"\$file\" \"\$dir/\${prefix}\${filename}\"
        echo \"✅ \$filename -> \$prefix\"
    fi
done
"

# АВТО-ПУШ НА GITHUB
cd ~/scripts/comfy-sort
git add sort_models.sh
git commit -m "Update to v$VERSION (Auto-revive logic)" --quiet
git push origin main --quiet && echo "☁️ Код синхронизирован с GitHub"
