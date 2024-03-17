# Home-Manager + Flakes for Mac/WSL and Droid

## Overview

This is my personal configuration that I use for WSL on Windows, MacOS, and my PixelFold. The WSL version primarily installs and configures my preferred shell with development and administration tools while the mac version configures the system and profile. The general approach here is to isolate my user configuration into `home` folder and system configurations in the `system` folder. There are some deviations from this. For instance, all of the secrets are user based, but they are decrypted from the system configuration because we get more control from agenix (owner and group permissions) and I have found this approach does not require any custom activations or a restart of wsl.

## General Project Structure

```Markdown
.
├─ home    # Home-manager and user configrations
├─ lib     # Shared functions that generate attribute sets
├─ nix     # Default Nix Configurations and Overlays
├─ setup   # Intitial Install/Configure Scripts
├─ system  # System / Host / Global configurations
```

## Influences & Inspirations

These public repositories heavily influenced my configuration. You'll see bit of stuff from each. In fact, most of the dot files in this project are directly pulled from EdenEast's public nix configuration. What they've done with [neovim/neovim](https://github.com/neovim/neovim) is mind blowing.

- [EdenEast/nyx](https://github.com/EdenEast/nyx)
- [dustinlyons/nixos-config](https://github.com/dustinlyons/nixos-config)

## Installation & Configuration

### Secrets Configuration

This repository uses [ryantm/agenix](https://github.com/ryantm/agenix) to manage secrets. The secrets are stored as encrypted age files in a private repository. To run this as is, you will need to either remove all references to secrets or create your own secrets repository.

The easiest way to run this is to create an empty secrets repository and update the inputs in flake.nix. Then make sure the options in '/system/$darwin or $wsl2>/hosts/$hostname/default.nix are all marked false as shown below. This will maintain the secrets skeleton, but should not error since no decryption configuration is provided.

```nix
  nyx = {
    modules = {
      user.home = ../../shared/home.nix;
    };

    secrets = {
      awsSSHKeys.enable = false;
      awsConfig.enable = false;
      userSSHKeys.enable = false;
      userPGPKeys.enable = false;
    };

    profiles = {
      desktop = {
        enable = true;
      };
    };
  };
```

If you want to actually build and decrypt secrets, here is what my secrets repository looks like:

```Markdown
.
├─ secrets.nix    # The secrets file you're instructed to create in this tutorial => https://github.com/ryantm/agenix?tab=readme-ov-file#tutorial
├─ encrypted      # Subdirectory to hold encrypted files
├─── id_ed25519.age files  # Example encrypted file
```

* Note that if the repository is private and you're using sudo, it will be looking for the github ssh key in the `/root/.ssh` directory and not your user directory.

### WSL2 Installation

1. Make sure you have WSL enabled and installed. [Click here if you need help setting up basic WSL2.](https://learn.microsoft.com/en-us/windows/wsl/install)
2. Make sure you have git installed in windows. You can download it [here.](https://git-scm.com/downloads) 
3. Open up a PowerShell window
4. Clone this repo and start the windows side of the installation by executing [start_here.ps1](https://github.com/mwdavisii/nyx/blob/main/setup/wsl/start_here.ps1).

```powershell
git clone https://github.com/mwdavisii/nyx.git
set-location ./nyx/setup/wsl
./start_here.ps1
```

5. You should now be in your windows user directory, but in the NixOS shell. Move back into the startup directory and launch [step2.sh](https://github.com/mwdavisii/nyx/blob/main/setup/wsl/step2.sh).

```shell
cd ./nyx/setup/wsl
./step2.sh
```

6. Before running the last step, open ./flake.nix in your favorite text editor and look for the lines below and change the following values:

- **displayName** => Display Name used in GitHub config
- **email** => Display Name used in GitHub config`
- **signingKey** => The key used to sign git commits. (you can leave blank)`
- **windowsUserDirName** => This is the folder name of your windows profile. It is used to create the symlink from WSL to VS Code and add it to your path.

****Note:*** Leave the userName as nixos for wsl unless you know how to configure non-default users in nixos for WSL. As of now, it requires building from [nix-community/NixOS-WSL](https://github.com/nix-community/NixOS-WSL) which is more than I can care to tackle at the moment.

```nix
{
  userName = "nixos";
  email = "mwdavisii@gmail.com";
  displayName = "Mike D.";
  signingKey = "5A60221930345909";
  windowsUserDirName = "mwdav";
}
```

7. Finally, run the last script, [step3.sh](https://github.com/mwdavisii/nyx/blob/main/setup/wsl/step3.sh).

```shell
./step3.sh
```

Now close the current shell and open a new one. After the initial install, you can apply updates by executing the refresh script. 

``` shell
./switch.sh #Rebuilds and switches to the home environment.
```

### MacOS Installation

1. Make sure you have git installed. You can download it [here.](https://git-scm.com/downloads) 
2. Clone this repository.

```shell
git clone https://github.com/mwdavisii/nyx.git
cd ./nyx/macos
```

3. Launch the installation script

```shell
./start_here.sh
```

4. Copy the `./users/mwdavisii.nix` file into a new file with your username. Then use your favorite text editor and update the information in the file. You can safely ignore the windowsUserDirName value, that is exclusively for WSL2 and VS Code.

- **displayName** => Display Name used in GitHub config
- **email** => Display Name used in GitHub config`
- **signingKey** => The key used to sign git commits. (you can leave blank)`

```nix
{
  userName = "mwdavisii";
  email = "mwdavisii@gmail.com";
  displayName = "Mike D.";
  signingKey = "5A60221930345909";
  windowsUserDirName = "";
}

```

5. Edit the `./flake.nix` file and look for the following lines. Change the user to the user you created above and if you are running an intel mac, change `aarch64-darwin` to `x86_64-darwin`.

```nix
darwinConfigurations = mapAttrs' mkDarwinConfiguration{
        mwdavis-workm1 = {system = "aarch64-darwin"; user = "mwdavisii";};
      };
```

6. Apply the changes

```shell
./step2.sh
```

7. Now close the current shell and open a new one. After the initial install, you can apply updates by executing the refresh script.

```shell
./switch.sh #Rebuilds and switches to the home environment.
```

### Android Installation

1. You will need to install [Nix-on-Droid from f-droid](https://f-droid.org/en/packages/com.termux.nix/)
2. Go into the root of the initial installation and edit `~/.config/nixpkgs/nix-on-droid.nix` to add 'git' to the packages
3. run `nix-on-droid switch --flake .` from the directory with `flake.nix` in it.
4. Once complete, run `git clone https://github.com/mwdavisii/nyx.git`
5. Run `cd nyx` and the run `nix-on-droid switch --flake .`

Note that NixOnDroid is still rudimentary and doesn't have full support for attrs and other utilities yet. This install still runs bash, but it does have neovim and several other functional tools.

## Tips and Tricks

I have over 126 commits in this project and those all came after I had an initial version running and deleted my .git folder before making this public. I am not new to declarative systems and have been using git ops strategies since they had a name, but Nix was brand new to me and trying to pick up Nix + Flakes + Attributes at the same time was hard for me. I can't tell you how many `git reset --hard` commands I've executed.

Here are some things that would have shortned my learning curve:

### Recommended Reading

- [EdenEast's Nyx Readme](https://github.com/EdenEast/nyx/blob/main/readme.md) The primary inspiration for this project 
- [Introduction to Nix & NixOS](https://nixos-and-flakes.thiscute.world/introduction/) A great overview
- [An Introduction to Nix Flakes](https://www.tweag.io/blog/2020-05-25-flakes/)
- [Flakes aren't real and cannot hurt you: a guide to using Nix flakes the non-flake way](https://jade.fyi/blog/flakes-arent-real/)

### My Nix, Flake, and mkAttribute Gotchas

- There is a lot of basic documentation and examples for nixos, flakes, and most modules. However, when introduce attribute sets, I found it more difficult to apply the published examples to the more complex approach. This was a lot of looking at other peoples repos, asking gemini for help, and a good bit of trial and error.
- I tried to be pure, but quickly found out the variation between systems and packages didn't always allow it. 
  - For instance, I would have put all user secrets inside of `home/` instead of `system/`, but I kept having issues with [ryantm/agenix](https://github.com/ryantm/agenix) and didn't want to use a custom activation script.
- Rollback a buil that successfuly failed by executing `nixos-rebuild switch --rollback`
  - I was frequently reloading the entire system when I had issues before I knew this.
- `nyx.modules`, `nyx.profiles`, and `nyx.secrets`
  - In each `mk${system}Configuration`, the lines below actually create the root options (`config.nyx.profiles`, `config.nyx.modules`,  and `config.nyx.secrets`).
  - These options are set in `system/$system/hosts/$hostname/default.nix`.
  - These options are applied from various subdirectories:
    - Secrets (`config.nyx.secrets`) are applied from `system/shared/secrets`
    - Profiles (`config.nyx.profiles`) are applied from `system/shared/profiles`
    - Modules (these are applied by home-manager)
      - App Modules (`config.nyx.modules.app`) are applied from `home/shared/modules/app`
      - Dev Modules (`config.nyx.modules.dev`) are applied from `home/shared/modules/dev`
      - Shell Modules (`config.nyx.modules.shell`) are applied from `home/shared/modules/shell`

Example from `lib/default.nix`:

```nix
  (import ../system/shared/modules)
  (import ../system/shared/profiles)
  (import ../in/secrets)
  (import (strToPath config ../in/hosts))
```

Example from `system/$system/hosts/$hostname/default.nix`:

```nix
  nyx = {
    modules = {
      user.home = ./home.nix;
    };
    secrets = {
      awsSSHKeys.enable = true;
      awsConfig.enable = true;
      userSSHKeys.enable = true;
      userPGPKeys.enable = true;
    };
    profiles = {
      desktop = {
        enable = true;
      };
    };
  };
```