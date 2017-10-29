# arch-install-script
An incredibly simple arch install script. This installs a very minimal arch install onto your hardware. It is highly recommended to both know how to install arch and to change the script according to your specific installation.


This script does not connect to the internet for you or create new partitions. That must be done before hand.


To run it:

    pacman -Sy git
    git clone https://github.com/cheertarts/arch-install-script.git
    cd arch-install-script
    chmod +x arch-install-script
    chmod +x arch-install-script-part-2
    ./arch-install-script
