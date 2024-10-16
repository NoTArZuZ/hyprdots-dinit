#!/usr/bin/env bash
#|---/ /+--------------------------+---/ /|#
#|--/ /-| Main installation script |--/ /-|#
#|-/ /--| Prasanth Rangan          |-/ /--|#
#|/ /---+--------------------------+/ /---|#

cat << "EOF"

-------------------------------------------------
        .
       / \         _       _  _      ___  ___ 
      /^  \      _| |_    | || |_  _|   \| __|
     /  _  \    |_   _|   | __ | || | |) | _| 
    /  | | ~\     |_|     |_||_|\_, |___/|___|
   /.-'   '-.\                  |__/          

-------------------------------------------------

EOF

#--------------------------------#
# import variables and functions #
#--------------------------------#
scrDir=$(dirname "$(realpath "$0")")
source "${scrDir}/global_fn.sh"
if [ $? -ne 0 ]; then
    echo "Error: unable to source global_fn.sh..."
    exit 1
fi

echo "WARNING: before you continue make sure you've connected Arch repos to pacman [extra] and [multilib]"
read -p "Press y to continue or n to abort: " archrepos
case ${archrepos} in
    [Yy]* ) echo "Continuing...";;
    [Nn]* ) echo "Exiting..."; exit 1;;
    * ) exit 1;;
esac

#------------------#
# evaluate options #
#------------------#
flg_Install=0
flg_Restore=0
flg_Service=0

while getopts idrs RunStep; do
    case $RunStep in
        i)  flg_Install=1 ;;
        d)  flg_Install=1 ; export use_default="--noconfirm" ;;
        r)  flg_Restore=1 ;;
        s)  flg_Service=1 ;;
        *)  echo "...valid options are..."
            echo "i : [i]nstall hyprland without configs"
            echo "d : install hyprland [d]efaults without configs --noconfirm"
            echo "r : [r]estore config files"
            echo "s : enable system [s]ervices"
            exit 1 ;;
    esac
done

if [ $OPTIND -eq 1 ]; then
    flg_Install=1
    flg_Restore=1
    flg_Service=1
fi

#--------------------#
# pre-install script #
#--------------------#
if [ ${flg_Install} -eq 1 ] && [ ${flg_Restore} -eq 1 ]; then
    cat << "EOF"
                _         _       _ _
 ___ ___ ___   |_|___ ___| |_ ___| | |
| . |  _| -_|  | |   |_ -|  _| .'| | |
|  _|_| |___|  |_|_|_|___|_| |__,|_|_|
|_|

EOF

    "${scrDir}/install_pre.sh"
fi

#------------#
# installing #
#------------#
if [ ${flg_Install} -eq 1 ]; then
    cat << "EOF"

 _         _       _ _ _
|_|___ ___| |_ ___| | |_|___ ___
| |   |_ -|  _| .'| | | |   | . |
|_|_|_|___|_| |__,|_|_|_|_|_|_  |
                            |___|

EOF

    #----------------------#
    # prepare package list #
    #----------------------#
    shift $((OPTIND - 1))
    cust_pkg=$1
    cp "${scrDir}/custom_hypr.lst" "${scrDir}/install_pkg.lst"

    if [ -f "${cust_pkg}" ] && [ ! -z "${cust_pkg}" ]; then
        cat "${cust_pkg}" >> "${scrDir}/install_pkg.lst"
    fi

    #--------------------------------#
    # add nvidia drivers to the list #
    #--------------------------------#
    if nvidia_detect; then
        cat /usr/lib/modules/*/pkgbase | while read krnl; do
            echo "${krnl}-headers" >> "${scrDir}/install_pkg.lst"
        done
        nvidia_detect --drivers >> "${scrDir}/install_pkg.lst"
    fi

    nvidia_detect --verbose

    #----------------#
    # get user prefs #
    #----------------#
    if ! chk_list "aurhlpr" "${aurList[@]}"; then
        echo -e "Available aur helpers:\n[1] yay\n[2] yay (bin)\n[3] paru\n[4] paru (bin)"
        prompt_timer 120 "Enter option number [default: yay] "

        case "${promptIn}" in
            1) export getAur="yay" ;;
            2) export getAur="yay-bin" ;;
            3) export getAur="paru" ;;
            4) export getAur="paru-bin" ;;
            *) echo -e "...Invalid option selected..." ; exit 1 ;;
        esac
    fi

    if ! chk_list "myShell" "${shlList[@]}"; then
        echo -e "Select shell:\n[1] zsh\n[2] fish"
        prompt_timer 120 "Enter option number"

        case "${promptIn}" in
            1) export myShell="zsh" ;;
            2) export myShell="fish" ;;
            *) echo -e "...Invalid option selected..." ; exit 1 ;;
        esac
        echo "${myShell}" >> "${scrDir}/install_pkg.lst"
    fi

    #--------------------------------#
    # install packages from the list #
    #--------------------------------#
    "${scrDir}/install_pkg.sh" "${scrDir}/install_pkg.lst"
    rm "${scrDir}/install_pkg.lst"
fi

#---------------------------#
# restore my custom configs #
#---------------------------#
if [ ${flg_Restore} -eq 1 ]; then
    cat << "EOF"

             _           _
 ___ ___ ___| |_ ___ ___|_|___ ___
|  _| -_|_ -|  _| . |  _| |   | . |
|_| |___|___|_| |___|_| |_|_|_|_  |
                              |___|

EOF

    "${scrDir}/restore_fnt.sh"
    "${scrDir}/restore_cfg.sh"
    echo -e "\n\033[0;32m[themepatcher]\033[0m Patching themes..."
    while IFS='"' read -r null1 themeName null2 themeRepo
    do
        themeNameQ+=("${themeName//\"/}")
        themeRepoQ+=("${themeRepo//\"/}")
        themePath="${confDir}/hyde/themes/${themeName}"
        [ -d "${themePath}" ] || mkdir -p "${themePath}"
        [ -f "${themePath}/.sort" ] || echo "${#themeNameQ[@]}" > "${themePath}/.sort"
    done < "${scrDir}/themepatcher.lst"
    parallel --bar --link "${scrDir}/themepatcher.sh" "{1}" "{2}" "{3}" "{4}" ::: "${themeNameQ[@]}" ::: "${themeRepoQ[@]}" ::: "--skipcaching" ::: "false"
    echo -e "\n\033[0;32m[cache]\033[0m generating cache files..."
    "$HOME/.local/share/bin/swwwallcache.sh" -t ""
    if printenv HYPRLAND_INSTANCE_SIGNATURE &> /dev/null; then
        "$HOME/.local/share/bin/themeswitch.sh" &> /dev/null
    fi
fi

#---------------------#
# post-install script #
#---------------------#
if [ ${flg_Install} -eq 1 ] && [ ${flg_Restore} -eq 1 ]; then
    cat << "EOF"

             _      _         _       _ _
 ___ ___ ___| |_   |_|___ ___| |_ ___| | |
| . | . |_ -|  _|  | |   |_ -|  _| .'| | |
|  _|___|___|_|    |_|_|_|___|_| |__,|_|_|
|_|

EOF

    "${scrDir}/install_pst.sh"
fi

#------------------------#
# enable system services #
#------------------------#
if [ ${flg_Service} -eq 1 ]; then
    cat << "EOF"

                 _
 ___ ___ ___ _ _|_|___ ___ ___
|_ -| -_|  _| | | |  _| -_|_ -|
|___|___|_|  \_/|_|___|___|___|

EOF
# idk how to make it different way :(
echo "[dinit] Setting up services..."
mkdir -p ~/.config/dinit.d/boot.d
touch ~/.config/dinit.d/boot
echo -e "type=internal\nwaits-for.d=boot.d" > ~/.config/dinit.d/boot
sudo cp /etc/dinit.d/user/dbus ~/.config/dinit.d/
sudo cp /etc/dinit.d/user/pipewire ~/.config/dinit.d/
sudo cp /etc/dinit.d/user/pipewire-pulse ~/.config/dinit.d/
sudo cp /etc/dinit.d/user/wireplumber ~/.config/dinit.d/
sudo dinitctl enable dbus
sudo dinitctl enable bluetoothd
sudo dinitctl enable backlight
sudo dinitctl enable turnstiled
dinit -q &
echo -e "If script failed on this moment, try to enable user services yourself\ndbus pipewire pipewire-pulse wireplumber\nand then sddm"
dinitctl enable dbus
dinitctl enable pipewire
dinitctl enable pipewire-pulse
dinitctl enable wireplumber
sudo dinitctl enable sddm
fi
