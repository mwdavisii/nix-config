{ inputs, self, config, ... }:

with inputs;
with inputs.nixpkgs;
with inputs.nixpkgs.lib;

let
  strToPath = x: path:
    if builtins.typeOf x == "string"
    then builtins.toPath ("${toString path}/${x}")
    else x;
  strToFile = x: path:
    if builtins.typeOf x == "string"
    then builtins.toPath ("${toString path}/${x}.nix")
    else x;
in
rec {
    firstOrDefault = first: default: if !isNull first then first else default;
    existsOrDefault = x: set: default: if hasAttr x set then getAttr x set else default;
    ### Top Level Home - Designed for Home-Manager Only Systems (Like Ubunutu)
    mkHome = name: { config ? name, user ? "mwdavisii", system ? "aarch64-darwin" }:
    let
      #pkgs = inputs.self.legacyPackages."${system}";
      pkgs = inputs.self.legacyPackages.aarch64-darwin;
      userConf = import (strToFile user ../users);
      userOptions = strToPath config ../home/hosts;
      homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${userConf.userName}" else "/home/${userConf.userName}";
    in
    nameValuePair name (
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          {
            home = { inherit homeDirectory; };
            #home.stateVersion = "23.11";
            home.username = userConf.userName;
            imports =
              let
                home = mkUserHome { inherit system userConf; config = userOptions; };
              in
              [ home ];

            xdg.configFile."nix/nix.conf".text =
              let
                nixConf = import ../nix/conf.nix;
              in
              ''
                experimental-features = nix-command flakes
              '';

            nix = {
              package = pkgs.nixVersions.stable;
              extraOptions = "experimental-features = nix-command flakes";
            };

            nixpkgs = {
              config = import ../nix/config.nix;
              overlays = inputs.self.overlays."${system}";
            };
          }
        ];
        extraSpecialArgs =
          let
            self = inputs.self;
            user = userConf;
          in
          { inherit inputs name self system user; };
      }
    );

    # This make the user home directory. It is usually invoked from the system/host file or mkHome
    mkUserHome = { config, userConf, system ? "aarch64-darwin" }:
    { ... }: {
      imports = [
        (agenix.homeManagerModules.default)
        (import ../home/darwin/modules)
        (import ../home/wsl2/modules)
        (import config )
      ];
      
      # For compatibility with nix-shell, nix-build, etc.
      home.file.".nixpkgs".source = inputs.nixpkgs;
      home.sessionVariables = {
        NIX_PATH = "nixpkgs=$HOME/.nixpkgs\${NIX_PATH:+:}$NIX_PATH";
        EDITOR = "nvim";
        VISUAL = "nvim";
        COLORTERM = "truecolor"; 
        PATH = if !(userConf.windowsUserDirName=="") then "$PATH:/mnt/c/Users/${userConf.windowsUserDirName}/AppData/Local/Programs/Microsoft VS Code/bin:/mnt/c/Windows" else "$PATH";
      };
      
      # Use the same Nix configuration for the user
      xdg.configFile."nixpkgs/config.nix".source = ../nix/config.nix;

      # Re-expose self and nixpkgs as flakes.
      xdg.configFile."nix/registry.json".text = builtins.toJSON {
        version = 2;
        flakes =
          let
            toInput = input:
              {
                type = "path";
                path = input.outPath;
              } // (
                filterAttrs
                  (n: _: n == "lastModified" || n == "rev" || n == "revCount" || n == "narHash")
                  input
              );
          in
          [
            {
              from = { id = "nyx"; type = "indirect"; };
              to = toInput inputs.self;
            }
            {
              from = { id = "nixpkgs"; type = "indirect"; };
              to = toInput inputs.nixpkgs;
            }
          ];
      };
      home.stateVersion = "23.11";
    };

    nixpkgsWithOverlays = with inputs; rec {
        config = import ../nix/config.nix;
        overlays = [
          nix-on-droid.overlays.default
          nur.overlay
          (_final: prev: {
            # this allows us to reference pkgs.unstable
            unstable = import nixpkgs-unstable {
              inherit (prev) system;
              inherit config;
            };
          })
        ];
    };

    configurationDefaults = args: {
        nixpkgs = nixpkgsWithOverlays;
        home-manager.useGlobalPkgs = true;
        home-manager.useUserPackages = true;
        home-manager.backupFileExtension = "hm-backup";
        home-manager.extraSpecialArgs = args;
    };

    argDefaults = {
    inherit secrets inputs self nix-index-database;
        channels = {
            inherit nixpkgs nixpkgs-unstable;
        };
    };
    
    mkNixOnDroidConfiguration = name: {config ? name, user ? "", system ? "aarch64-linux", hostname ? "nix-on-droid", args ? {}, }: 
      nameValuePair name(
        let
            pkgs = import nixpkgs {
              system = "aarch64-linux";
              overlays = [
                nix-on-droid.overlays.default
                # add other overlays
              ];
            };
            userConf = import (strToFile user ../users);
        in
        nix-on-droid.lib.nixOnDroidConfiguration {
          inherit system;
          modules = [
/*
            (
              { inputs, ... }: {
                # Use the nixpkgs from the flake.
                nixpkgs = { inherit pkgs; };

                # For compatibility with nix-shell, nix-build, etc.
                environment.etc.nixpkgs.source = inputs.nixpkgs;
                nix.nixPath = [ "nixpkgs=/etc/nixpkgs" ];
              }
            )
*/
            (
              { pkgs, ... }: {
                # Don't rely on the configuration to enable a flake-compatible version of Nix.
                nix = {
                  package = pkgs.nixVersions.stable;
                  extraOptions = "experimental-features = nix-command flakes";
                };
              }
            )

          (
            { inputs, ... }: {
              # Re-expose self and nixpkgs as flakes.
              nix.registry = {
                self.flake = inputs.self;
                nixpkgs = {
                  from = { id = "nixpkgs"; type = "indirect"; };
                  flake = inputs.nixpkgs;
                };
              };
            }
          )
          (
            { ... }: {
              environment.etcBackupExtension = ".bak";
              system.stateVersion = "23.11";
            }
          )
          (
            {
              home-manager = {
                # useUserPackages = true;
                config = ../home/droid/home.nix;
                useGlobalPkgs = true;
                extraSpecialArgs =
                  let
                    self = inputs.self;
                    user = userConf;
                  in
                  # NOTE: Cannot pass name to home-manager as it passes `name` in to set the `hmModule`
                  { inherit inputs self system user userConf secrets; };
              };
            }
          )
          #(import ../system/common/modules)
          #(import ../system/common/profiles)
          #(import ../system/droid/modules)
          (import (strToPath config ../system/droid/hosts))

      ];
      extraSpecialArgs =
        let
          self = inputs.self;
          user = userConf;
        in
        { inherit inputs self system user userConf secrets agenix home-manager; };
      }
    );


    mkNixosWSLConfiguration = name: {config ? name, user ? "nixos", system ? "x86_64-linux", hostname ? "nixos", args ? {}, }: 
    nameValuePair name(
        let
            pkgs = inputs.self.legacyPackages."${system}";
            userConf = import (strToFile user ../users);
        in
        nixosSystem {
        inherit system;
        modules = [
          (
            {
              environment.systemPackages = [ agenix.packages.${system}.default ];
              age.identityPaths = [ "/home/${userConf.userName}/.ssh/id_rsa" ];
              
            }
          )
          (inputs.nixos-wsl.nixosModules.wsl)
          (
            { name, ... }: {
              networking.hostName = name;
            }
          )
          (
            { inputs, ... }: {
              # Use the nixpkgs from the flake.
              nixpkgs = { inherit pkgs; };

              # For compatibility with nix-shell, nix-build, etc.
              environment.etc.nixpkgs.source = inputs.nixpkgs;
              nix.nixPath = [ "nixpkgs=/etc/nixpkgs" ];
            }
          )
          (
            { pkgs, ... }: {
              # Don't rely on the configuration to enable a flake-compatible version of Nix.
              nix = {
                package = pkgs.nixVersions.stable;
                extraOptions = "experimental-features = nix-command flakes";
              };
            }
          )
          (
            { inputs, ... }: {
              # Re-expose self and nixpkgs as flakes.
              nix.registry = {
                self.flake = inputs.self;
                nixpkgs = {
                  from = { id = "nixpkgs"; type = "indirect"; };
                  flake = inputs.nixpkgs;
                };
              };
            }
          )
          (
            { ... }: {
              system.stateVersion = "23.11";
            }
          )
          (vscode-server.nixosModules.default)
          (
            { config, pkgs, ... }: {
              services.vscode-server.enable = true;
            }
          )
          (inputs.agenix.nixosModules.default)
          (inputs.home-manager.nixosModules.home-manager)
          (
            {
              home-manager = {
                # useUserPackages = true;
                useGlobalPkgs = true;
                extraSpecialArgs =
                  let
                    self = inputs.self;
                    user = userConf;
                  in
                  # NOTE: Cannot pass name to home-manager as it passes `name` in to set the `hmModule`
                  { inherit inputs self system user userConf secrets; };
              };
            }
          )
          (import ../system/shared/modules)
          (import ../system/shared/profiles)
          (import ../system/shared/secrets)
          (import ../system/wsl2/modules)
          (import (strToPath config ../system/wsl2/hosts))
        ];
        specialArgs =
          let
            self = inputs.self;
            user = userConf;
          in
          { inherit inputs name self system user userConf hostname secrets;};
      }
    );
    
    mkDarwinConfiguration = name: {config ? name, user ? "nixos", system ? "aarch64-darwin", args ? {}, }: 
    nameValuePair name (
        let
            pkgs = inputs.self.legacyPackages."${system}";
            userConf = import (strToFile user ../users);
        in
        inputs.darwin.lib.darwinSystem {
            inherit system;            
            modules = [
                (
                  {
                    environment.systemPackages = [ agenix.packages.${system}.default ];
                  }
                )
                (
                  { inputs, ... }: {
                      # Re-expose self and nixpkgs as flakes.
                      nix.registry = {
                          self.flake = inputs.self;
                          nixpkgs = {
                          from = { id = "nixpkgs"; type = "indirect"; };
                          flake = inputs.nixpkgs;
                          };
                      };
                    }
                )
                (
                  { pkgs, ... }: {
                    # Don't rely on the configuration to enable a flake-compatible version of Nix.
                    nix = {
                      package = pkgs.nixVersions.stable;
                      extraOptions = "experimental-features = nix-command flakes";
                    };
                    services.nix-daemon.enable = true;
                    # users.nix.configureBuildUsers = true; # Not sure I am ready for this
                  }
                )
                (inputs.agenix.darwinModules.default)
                (inputs.home-manager.darwinModules.home-manager)
                (
                    {
                        home-manager = {
                            useGlobalPkgs = true;
                            extraSpecialArgs =
                            let
                                self = inputs.self;
                                user = userConf;
                            in
                            { inherit inputs pkgs self system user userConf secrets; };
                        };
                    }
                )
                (
                  { config, ... }: {
                    system.activationScripts.applications.text = pkgs.lib.mkForce (
                        ''
                            echo "setting up ~/Applications/Nix..."
                            rm -rf ~/Applications/Nix
                            mkdir -p ~/Applications/Nix
                            chown ${userConf.userName} ~/Applications/Nix
                            find ${config.system.build.applications}/Applications -maxdepth 1 -type l | while read f; do
                            src="$(/usr/bin/stat -f%Y $f)"
                            appname="$(basename $src)"
                            osascript -e "tell app \"Finder\" to make alias file at POSIX file \"/Users/${userConf.userName}/Applications/Nix/\" to POSIX file \"$src\" with properties {name: \"$appname\"}";
                        done
                        ''
                    );
                  }
                )
                (import ../system/shared)
                (import ../system/darwin/modules)
                (import (strToPath config ../system/darwin/hosts))
        ];
            specialArgs =
            let
                self = inputs.self;
                user = userConf;
            in
            { inherit inputs name self system user userConf secrets pkgs; };
        }
    );
}