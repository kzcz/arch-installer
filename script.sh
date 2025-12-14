#!/usr/bin/bash
set +hH -o posix
alias ask='read -rep'
[ -d /sys/firmware/efi ] && EFI=true || EFI=false
BASEPKGS="base base-devel git networkmanager bash-completion grub"
$EFI && BASEPKGS="$BASEPKGS efibootmgr"
XTRAPKG=""
LINUX=linux
PRT1=vfat
EDITOR=vim
GRTR=''
FSUP=''
SHL=bash
SHCMP=''
yno() {
echo "<@> $1?"
PS3="--> "
select A in yes no; do
    case $A in
        yes) return 0; ;;
        no) return 1; ;;
        *) echo "Invalid answer"; ;;
    esac
done
unset
}
echo "Installing requirements."
pacman -Sy fzf rsync --noconfirm --quiet
PS3="Linux # "
select A in "Linux" "Linux LTS" "Linux Zen" "Linux Hardened" "info" "quit"; do case $A in 
    "quit") exit; ;;
    "Linux") LINUX=linux; break; ;;
    "Linux Hardened") LINUX=linux-hardened; break; ;;
    "Linux LTS") LINUX=linux-lts; break; ;;
    "Linux Zen") LINUX=linux-zen; break; ;;
    info) printf \
"Hardened Linux ---> Linux with additional checks like smash protection. Not recommended for desktop usage.\n"\
"Linux LTS      ---> Long term support versions, updates less regularly but has more support.\n"\
"Linuz Zen      ---> Linux with more optimizations, less support but better performance.\n"\
"Linux          ---> Everyday linux, updates regularly with the latest features.\n"; ;;
	*) echo "Bad option."; ;;
esac; done
yno "Use a graphical environment." && {
PS3="Env # "
select A in "XFCE base" "XFCE full" "KDE base" "KDE full" "GNOME min" "GNOME base" "GNOME extra" "i3" "info"; do case $A in
    "XFCE base") XTRAPKG="xfce4 lightdm lightdm-gtk-greeter"; GRTR="lightdm"; break; ;;
    "XFCE full") XTRAPKG="xfce4 xfce4-goodies lightdm lightdm-gtk-greeter"; GRTR="lightdm"; break; ;;
    "KDE base") XTRAPKG="plasma-desktop plasma-workspace plasma-systemmonitor systemsettings kwin kscreen powerdevil plasma-nm plasma-pa polkit-kde-agent kde-gtk-config kdeplasma-addons plasma-integration print-manager breeze flatpak-kcm plasma-activities sddm discover konsole sddm-kcm"; GRTR="sddm"; break; ;;
    "KDE full") XTRAPKG="plasma sddm sddm-kcm"; GRTR="sddm"; break; ;;
    "GNOME min") XTRAPKG="baobab gdm gnome-backgrounds gnome-calculator gnome-calendar gnome-characters gnome-clocks gnome-color-manager gnome-console gnome-contacts gnome-control-center gnome-disk-utility gnome-font-viewer gnome-keyring gnome-logs gnome-menus gnome-session gnome-settings-daemon gnome-shell gnome-shell-extensions gnome-system-monitor gnome-text-editor gnome-tour nautilus xdg-desktop-portal-gnome xdg-user-dirs-gtk"; GRTR="gdm"; break; ;;
    "GNOME base") XTRAPKG="gnome"; GRTR="gdm"; break; ;;
    "GNOME extra") XTRAPKG="gnome gnome-extra"; GRTR="gdm"; break; ;;
    "i3") XTRAPKG="i3-wm i3status i3lock i3blocks dmenu xorg-server xorg-xinit xterm alacritty lightdm lightdm-gtk-greeter xorg-xinput xorg-xev"; GRTR="lightdm"; break; ;;
    "info") echo "XFCE, KDE and GNOME are desktop environments. i3 is a window manager."; ;;
esac; done; }
yno "Install openssh" && XTRAPKG="$XTRAPKG openssh"; echo
yno "Install fastfetch" && XTRAPKG="$XTRAPKG fastfetch"; echo
yno "Install tmux" && XTRAPKG="$XTRAPKG tmux"; echo
$EFI && yno "Install and enable os-prober" && { XTRAPKG="$XTRAPKG os-prober"; OS_PROBER=true; } || OS_PROBER=false;
echo
echo "Select a shell"
select A in bash zsh fish; do case $A in
    bash) SHL=bash; SHCMP=""; break; ;;
    zsh) SHL=zsh; SHCMP="zsh-autocomplete zsh-completions"; break; ;;
    fish) SHL=fish; SHCMP=""; break; ;;
esac; done
XTRAPKG="$XTRAPKG $SHL $SHCMP"
echo "Select an editor."
select A in nano vim emacs none; do case $A in
    nano) EDITOR=nano; break; ;;
    vim) EDITOR=vim; break; ;;
    emacs) EDITOR=emacs; break; ;;
    none) EDITOR=''; break; ;;
esac; done
export EDITOR
XTRAPKG="$XTRAPKG $EDITOR"
reflector --save /etc/pacman.d/mirrorlist --threads 3 -f 5 -c $( curl -s https://cloudflare.com/cdn-cgi/trace | grep 'loc=' | cut -d= -f2 ) 2>/dev/null &
yno "Automatic partitioning" && {
DISKS=($(lsblk -nd -o NAME))
if [[ ${#DISKS[@]} == 1 ]] then
    DISK=${DISK[0]}
else
    lsblk -d -o NAME,SIZE,VENDOR,MODEL
    PS3="Disk # "
    select A in ${DISKS[@]}; do
        [ -n $A ] && break;
    done
    DISK=/dev/$A
fi
echo "Select a format for the '/' partition. ext4 or btrfs recommended."
PS3="FS # "
select A in ext4 btrfs xfs f2fs; do case $A in
    ext4) PRT2="ext4 -F"; FSUP=''; break; ;;
    btrfs) PRT2="btrfs -f"; FSUP='btrfs-progs'; break; ;;
    xfs) PRT2="xfs -f"; FSUP='xfsprogs'; break; ;;
    f2fs) PRT2="f2fs -f"; FSUP='f2fs-tools'; break; ;;
esac; done
XTRAPKG="$XTRAPKG $FSUP"
umount ${DISK}* &>/dev/null
rm -rf /mnt
mkdir /mnt
if $EFI; then
    printf $'g\nn\n\n\n+1G\nt\n1\nn\n\n\n\nt\n2\n23\np\nw\n' | fdisk -W always -w always $DISK
else
    printf $'o\nn\n\n\n\n+1G\na\nn\n\n\n\n\np\nw\n' | fdisk -W always -w always $DISK
fi
mkfs.vfat ${DISK}1
mkfs.$PRT2 -q ${DISK}2
mount ${DISK}2 /mnt -v
mount ${DISK}1 /mnt/boot --mkdir -v
} || { echo "mount /mnt and /mnt/boot yourself."; bash && [ -d /mnt -a -d /mnt/boot ] || {echo "Try partitioning automatically instead."; exit 1}; }
echo "Patching pacman.conf"
sed -i '33s/#//; 37s/#//; 37s/5/4/' /etc/pacman.conf
echo "Waiting for reflector to finish."
wait
pacstrap -K /mnt $BASEPKGS $XTRAPKG $LINUX
export LANG=$(cat /usr/share/i18n/SUPPORTED | awk '{printf $1 "\0"}' | fzf --read0 --prompt="Language> "); echo
export TZ=$(find /usr/share/zoneinfo/ ! -wholename '*/posix/*' ! -wholename '*/right/*' ! -name '*.*' -type f | cut -b 21- | fzf --prompt='Timezone> '); echo
ln -sf /usr/share/zoneinfo/$TZ /mnt/etc/localtime
[ $EDITOR ] && { echo "EDITOR=$(which $EDITOR)" >> /mnt/etc/environment; }
arch-chroot /mnt hwclock --systohc
sed -i "s/#$LANG /$LANG /" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
sed -i '121s/# //' /mnt/etc/sudoers
echo "LANG=$LANG" > /mnt/etc/locale.conf
export KEYMAP=$(localectl list-keymaps | fzf --prompt='Keymap> '); echo
echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
arch-chroot /mnt chsh -s $(which $SHL) $USRN
read -rep "Hostname > " HSTN
echo "$HSTN" > /mnt/etc/hostname
read -rep "Username > " USRN
arch-chroot /mnt useradd -mG wheel,video $USRN
echo "Password for $USRN"
until arch-chroot /mnt passwd $USRN; do echo "passwd for $USRN failed... restarting"; done
echo "Password for root"
until arch-chroot /mnt passwd root; do echo "passwd for root failed... restarting"; done
systemd-nspawn -D /mnt systemctl enable NetworkManager.service
[ -n "$GRTR" ] && systemd-nspawn -D /mnt systemctl enable $GRTR
$OS_PROBER && sed -i '63s/#//' /etc/default/grub
$EFI && {
    arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=Arch
} || {
    arch-chroot /mnt grub-install --target=i386-pc /dev/sda
}
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg
cp /etc/pacman.conf /mnt/etc/
B='AH=$A;break; ;;\n'
printf "#!/usr/bin/bash\necho 'Select an AUR helper to install.'\nAH=''\nselect A in paru aura yay rua; do case \$A in\n\tparu) $B\n\taura) $B\n\tyay) $B\n\trua) $B\nesac; done\ngit clone https://aur.archlinux.org/\${A}.git\ncd \$A\nmakepkg -risc\ncd ..\nrm -rfv \$A\n" > /mnt/home/$USRN/install_aur_helper.sh
chmod 0755 /mnt/home/$USRN/install_aur_helper.sh
sed -i '125s/#//' /mnt/etc/sudoers  
echo "Once you boot onto your system, try executing ~/install_aur_helper.sh!"
