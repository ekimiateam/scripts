#!/bin/bash

VERSION=230625

downloaded_file=""

function menu_flash() {
    if zenity --question --title="EKIMIA EOSUPGRADER ${VERSION}" --text="Bienvenue ! Veuillez cliquer sur 'Détecter mon appareil' pour continuer." --ok-label="Détecter mon appareil" --cancel-label="Quitter"; then

        device_name=$(adb shell getprop ro.product.device 2>/dev/null)
        lineage_name=$(adb shell getprop ro.lineage.device 2>/dev/null)

        if [ -n "$device_name" ]; then
            if zenity --question --title="Appareil détecté" --text="Appareil : $device_name\nCode : $lineage_name\n\nVoulez-vous télécharger le zip correspondant ? (Version 3.0 de Android 13)" --ok-label="Accepter" --cancel-label="Refuser"; then
                download_zip "$lineage_name" "$device_name"

                if zenity --question --title="EKIMIA" --text="✅ Téléchargement réussi !\n\nMaintenant, pour continuer nous devons redémarrer votre appareil en mode recovery. Cliquez sur 'Accepter' pour continuer." --ok-label="Accepter" --cancel-label="Refuser"; then
                    adb reboot recovery
                    zenity --info --title="Mode recovery" --text="Veuillez patienter pendant que votre $device_name redémarre en mode recovery..." --timeout=15
                    zenity --info --title="Tuto" --text="Super !\n\nSur votre téléphone, utilisez les boutons *VOLUME* pour vous déplacer et le bouton *POWER* pour confirmer.\n\nAllez dans :\n\n• Apply update\n• Puis Apply from ADB\n\nUne fois fait, cliquez sur 'Valider' ici pour flasher votre appareil."

                    zip_path="/tmp/ekimia/$downloaded_file"

                    adb sideload "$zip_path" 2>&1 | \
                    sed -u 's/^[a-zA-Z\-].*//; s/.* \{1,2\}\([0-9]\{1,3\}\)%.*/\1\n#Flash en cours... \1%/; s/^20[0-9][0-9].*/#Done./' | \
                    zenity --progress --percentage=0 --title="$device_name" --text="⏳ Flash en cours...\n\nMême si l’écran du téléphone semble bloqué à 47%, c’est normal.\n\nMerci de patienter jusqu’à la fin du processus." --auto-close --auto-kill

                    zenity --info --title="✅ Flash réussi" --text="Félicitations ! 🎉\n\nVotre $device_name a été flashé avec succès.\n\nSur votre téléphone, sélectionnez *Reboot system now* pour redémarrer normalement.\n\nMerci d’avoir utilisé l’outil EKIMIA !"
                else
                    exit
                fi

            else
                exit
            fi
        else
            zenity --error --title="Erreur ADB" --text="Aucun appareil détecté.\n\nVeuillez vérifier que :\n- Le débogage USB est activé\n- Le câble est bien branché"
        fi
    else
        exit
    fi
}

function download_zip() {
    local codename="$1"
    local device_title="$2"

#    codename="instantnoodlep"
#    device_title="8PROOO"

    mkdir -p /tmp/ekimia
    local url=""

    case "$codename" in
        enchilada)
            url="https://images.ecloud.global/community/enchilada/e-3.0.1-t-20250609499174-community-enchilada.zip"
            ;;
        kane)
            url="https://images.ecloud.global/community/kane/e-3.0.1-t-20250609499174-community-kane.zip"
            ;;
        oriole)
            url="https://images.ecloud.global/community/oriole/e-3.0.1-t-20250608499173-community-oriole.zip"
            ;;
        hotdogb)
            url="https://images.ecloud.global/community/hotdogb/e-3.0.1-t-20250606498934-community-hotdogb.zip"
            ;;
        ocean)
            url="https://images.ecloud.global/community/ocean/e-3.0.1-t-20250608499173-community-ocean.zip"
            ;;
        nairo)
            url="https://images.ecloud.global/community/nairo/e-3.0.1-t-20250608499173-community-nairo.zip"
            ;;
        lake)
            url="https://images.ecloud.global/community/lake/e-3.0.1-t-20250609499174-community-lake.zip"
            ;;
        guacamoleb)
            url="https://images.ecloud.global/community/guacamoleb/e-3.0.1-t-20250606498934-community-guacamoleb.zip"
            ;;
        lemonade)
            url="https://images.ecloud.global/community/lemonade/e-3.0.1-t-20250606498934-community-lemonade.zip"
            ;;
        lancelot)
            url="https://images.ecloud.global/community/lancelot/e-3.0.1-t-20250609499174-community-lancelot.zip"
            ;;
        crownite)
            url="https://images.ecloud.global/community/crownlte/e-3.0.1-t-20250609499174-community-crownlte.zip"
            ;;
        kebab)
            url="https://images.ecloud.global/community/kebab/e-3.0.1-t-20250609499174-community-kebab.zip"
            ;;
        instantnoodlep)
            url="https://images.ecloud.global/community/instantnoodlep/e-3.0.1-t-20250609499174-community-instantnoodlep.zip"
            ;;
        instantnoodle)
            url="https://images.ecloud.global/community/instantnoodle/e-3.0.4-t-20250710507811-community-instantnoodle.zip"
            ;;   
        dumpling)
            url="https://images.ecloud.global/community/dumpling/e-3.0.1-t-20250609499174-community-dumpling.zip"
            ;;
        beyond0lte)
            url="https://images.ecloud.global/community/beyond0lte/e-3.7.2-t-20260423612682-community-beyond0lte.zip"
            ;;
        *)
            zenity --error --title="EKIMIA" --text="Appareil non reconnu : $codename\n\nVeuillez contacter le support Ekimia."
            exit 1
            ;;
    esac

    downloaded_file=$(basename "$url")

    wget -P /tmp/ekimia "$url" 2>&1 | \
        sed -u 's/^[a-zA-Z\-].*//; s/.* \{1,2\}\([0-9]\{1,3\}\)%.*/\1\n#Téléchargement en cours... \1%/; s/^20[0-9][0-9].*/#Done./' | \
        zenity --progress --percentage=0 --title="$device_title" --text="Démarrage du téléchargement..." --auto-close --auto-kill
}

menu_flash
