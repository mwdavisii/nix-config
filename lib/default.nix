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

  # Top level derivation for just home-manager
  mkHome = name: { config ? name, user, system ? "x86_64-linux" }:
    let
      pkgs = inputs.self.legacyPackages."${system}";
      userConf = import (strToFile user ../users);
      username = user;
      homeDirectory = if pkgs.stdenv.isDarwin then "/Users/${username}" else "/home/${username}";
    in
    nameValuePair name (
      inputs.home-manager.lib.homeManagerConfiguration {
        inherit pkgs;
        modules = [
          {
            home = { inherit username homeDirectory; };

            imports =
              let
                userConf = strToPath config ../home/standalone/hosts;
                home = mkUserHome { inherit system; config = userConf; };
              in
              [ home ];
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
  mkUserHome = { config, system ? "x86_64-linux" }: {
    imports = [
      (import ../home/shared/modules)
      (import ../home/standalone/profiles)
      (import config)
    ];

    # For compatibility with nix-shell, nix-build, etc.
    home.file.".nixpkgs".source = inputs.nixpkgs;
    home.sessionVariables."NIX_PATH" =
      "nixpkgs=$HOME/.nixpkgs\${NIX_PATH:+:}$NIX_PATH";

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
    # TODO: Note sure where this should go
    home.sessionPath = [ "$HOME/.local/nyx/bin" "$XDG_BIN_HOME" ];
  } // (optionalAttrs inputs.nixpkgs.legacyPackages."${system}".stdenv.isLinux {
    targets.genericLinux.enable = true;
    xdg.mime.enable = true;
  });
  
  
  mkNixSystemConfiguration = name: { config ? name, user ? "nixos", system ? "x86_64-linux", hostname ? "nixos", buildTarget, args ? { }, }:
    nameValuePair name (
      let
        pkgs = inputs.self.legacyPackages."${system}";
        userConf = import (strToFile user ../users);
        unstable = import nixpkgs-unstable {inherit system;};
        #nixos = Dedicated Build on Metal
        nixosModules = [
          (hyprland.nixosModules.default)
          (inputs.home-manager.nixosModules.home-manager)
          (
            {
              home-manager = {
                # useUserPackages = true;
                useGlobalPkgs = true;
                useUserPackages = true;
                extraSpecialArgs =
                  let
                    self = inputs.self;
                    user = userConf;
                  in
                  # NOTE: Cannot pass name to home-manager as it passes `name` in to set the `hmModule`
                  { inherit inputs self system user userConf unstable secrets; };
              };
            }
          )
          (
            { ... }: {
              system.stateVersion = "24.05";
            }
          )
          (inputs.nixos-wsl.nixosModules.wsl)
          (vscode-server.nixosModules.default)
          (disko.nixosModules.disko)
          (inputs.agenix.nixosModules.default)
          (import ../system/nixos/modules)
          (import ../system/shared)
          (import (strToPath config ../system/nixos/hosts))
        ];
        #Darwin = Mac Target
        darwinModules = [
          (
            {
              services.nix-daemon.enable = true;
            }
          )
          (inputs.agenix.darwinModules.default)
          (inputs.home-manager.darwinModules.home-manager)
          (
            {
              home-manager = {
                useGlobalPkgs = true;
                useUserPackages = true;
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
                      chown mdavis67 ~/Applications/Nix
                      find ${config.system.build.applications}/Applications -maxdepth 1 -type l | while read -r f; do
                      src="$(/usr/bin/stat -f%Y "$f")"
                      appname="$(basename "$src")"
                      osascript -e "tell app \"Finder\" to make alias file at POSIX file \"/Users/mdavis67/Applications/Nix/\" to POSIX file \"$src\" with properties {name: \"$appname\"}";
                  done
                ''
              );
            }
          )
          
          (import ../system/darwin/modules)
          (import ../system/shared/secrets)
          (import ../system/shared/profiles/macbook.nix)
          (import (strToPath config ../system/darwin/hosts))
        ];
        commonModules = [
          (
            {
              environment.systemPackages = [ agenix.packages.${system}.default ];
              age.identityPaths = [ "/home/${userConf.userName}/.ssh/id_rsa" ];

            }
          )
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
          (import ../system/shared/secrets)
        ];
      in
      if buildTarget == "iso" then
        nixosSystem
          {
            inherit system;
            modules = commonModules ++ nixosModules ++ [
              #(import "${nixpkgs}/nixos/modules/installer/cd-dvd/installation-cd-minimal.nix") Default nix lib
              (inputs.nixos-generators.nixosModules.all-formats) #Community Nix Generators
            ];
            specialArgs =
              let
                self = inputs.self;
                user = userConf;
              in
              { inherit inputs name self system user userConf hostname secret; };
          }
      else if buildTarget == "wsl" then
        nixosSystem
          {
            inherit system;
            modules = commonModules ++ nixosModules;
            specialArgs =
              let
                self = inputs.self;
                user = userConf;
              in
              { inherit inputs name self system user userConf hostname secrets; };
          }
      ## handles nixos host builds
      else if buildTarget == "nixos" then
        nixosSystem
          {
            inherit system;
            modules = commonModules ++ nixosModules;
            specialArgs =
              let
                self = inputs.self;
                user = userConf;
              in
              { inherit inputs name self system user userConf hostname secrets; };
          }
      #handles VM builds. Default will not cross compile.
      else if buildTarget == "vm" then
        nixosSystem
          {
            inherit system;
            modules = commonModules ++ nixosModules ++ [
              (inputs.nixos-generators.nixosModules.all-formats)
            ];
            specialArgs =
              let
                self = inputs.self;
                user = userConf;
              in
              { inherit inputs name self system user userConf hostname secrets; };
          }

      else if buildTarget == "darwin" then
        inputs.darwin.lib.darwinSystem
          {
            inherit system;
            modules = commonModules ++ darwinModules;
            specialArgs =
              let
                self = inputs.self;
                user = userConf;
              in
              {
                inherit inputs name self system user userConf secrets pkgs;
              };
          }
      else
        throw "${systemType} is not supported."
    );

  ################################## DROID ##################################
  mkNixOnDroidConfiguration = name: { config ? name, user ? "", system ? "aarch64-linux", hostname ? "nix-on-droid", args ? { }, }:
    nameValuePair name (
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
}
    
