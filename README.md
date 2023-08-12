# Pterodactyl Installer

With this script you can easily install, update or delete Pterodactyl Panel. Everything is gathered in one script.
Use this script if you want to install, update or delete your services quickly. The things that are being done are already listed on [Pterodactyl](https://pterodactyl.io/), but this clearly makes it faster since it is automatic.

Please note that this script is made to work on a fresh installation. There is a good chance that it will fail if it is not a fresh installation.
The script must be run as root.

If you find any errors, things you would like changed or queries for things in the future for this script, please write an "Issue".
Read about [Pterodactyl](https://pterodactyl.io/) here. This script is not associated with the official Pterodactyl Project.

# Features
This script is one of the only ones that has a well-functioning Switch Domains feature.

- Install Panel
- Install Wings
- Install PHPMyAdmin
- Switch Pterodactyl Domains
- Uninstall Panel
- Uninstall Wings

# Supported OS & Webserver
Supported operating systems.

| Operating System | Version               | Supported                          |
| ---------------- | ----------------------| ---------------------------------- |
| Ubuntu           | from 18.04 to 22.04   | :white_check_mark:                 |
| Debian           | from 10 to 11         | :white_check_mark:                 |
| CentOS           | no supported versions | :x:                                |
| Rocky Linux      | no supported versions | :x:                                |

| Webserver        | Supported           |
| ---------------- | --------------------| 
| NGINX            | :white_check_mark:  |
| Apache           | :white_check_mark:  |
| LiteSpeed        | :x:                 |
| Caddy            | :x:                 |

# Copyright
Please do not say you created this script. You may create a fork for this Pterodactyl-Installer, but I would appreciate this github being linked to.
Also, please not remove my copyright at the top of the Pterodactyl-Installer script.

# Support
No support is offered for this script.
The script has been tested many times without any bug fixes, however they can still occur.
If you find errors, feel free to open an "Issue" on GitHub.

# Interactive/Normal installation
The recommended way to use this script.
Debian based systems only.
```bash
bash <(curl -s https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/installer.sh)
```

### Raspbian
Only for raspbian users. They might need a extra < in the beginning.
```bash
bash < <(curl -s https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/installer.sh)
```

# Autoinstall / Developer Installation
Only use this if you know what you are doing!
You can now install Pterodactyl using 1 command without having to manually type anything after running the command.

```
<fqdn> = What you want to access your panel with. Eg. panel.domain.ltd
<ssl> = Whether to use SSL. Options are true or false.
<email> = Your email. If you choose SSL, it will be shared with Lets Encrypt.
<username> = Username for admin account on Pterodactyl
<firstname> = First name for admin account on Pterodactyl
<lastname> = Lastname for admin account on Pterodactyl
<password> = The password for the admin account on Pterodactyl
<wings> = Whether you want to have Wings installed automatically as well. Options are true or false.
```

You must be precise when using this script. 1 typo and everything can go wrong.
It also needs to be run on a fresh version of Ubuntu or Debian.

```bash
bash <(curl -s https://raw.githubusercontent.com/dension0/Pterodactyl-Installer/main/autoinstall.sh)  <fqdn> <ssl> <email> <username> <firstname <lastname> <password> <wings>
```
