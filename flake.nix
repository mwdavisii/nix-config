{
  inputs = {
    # Core
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-unstable.url = "github:nixos/nixpkgs/nixos-unstable";
    nix-index-database.url = "github:nix-community/nix-index-database";
    nix-index-database.inputs.nixpkgs.follows = "nixpkgs";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nur.url = "github:nix-community/NUR";
    #hyprland
    hyprland.url = "git+https://github.com/hyprwm/Hyprland?submodules=1";
    #hyprland.url = "github:hyprwm/Hyprland/v0.38.1";
    hyprland-plugins = {
      url = "git+https://github.com/hyprwm/hyprland-plugins";
      inputs.hyprland.follows = "hyprland";
    };
    #hardware
    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #Virtualizationb
    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    kmonad = {
      url = "git+https://github.com/kmonad/kmonad?submodules=1&dir=nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Secrets
    agenix.url = "github:ryantm/agenix";
    secrets = {
      url = "git+ssh://git@github.com/mwdavisii/nix-secrets.git";
      flake = false;
    };

    # MacOS
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-24.05-darwin";
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-homebrew.url = "github:zhaofengli-wip/nix-homebrew";
    homebrew-bundle = {
      url = "github:homebrew/homebrew-bundle";
      flake = false;
    };
    homebrew-core = {
      url = "github:homebrew/homebrew-core";
      flake = false;
    };
    homebrew-cask ={
      url = "github:homebrew/homebrew-cask";
      flake = false;
    };

    # WSL
    vscode-server.url = "github:nix-community/nixos-vscode-server";
    nixos-wsl = {
      url = "github:nix-community/NixOS-WSL";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    #Droid
    nix-on-droid = {
      url = "github:nix-community/nix-on-droid/release-23.11";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.home-manager.follows = "home-manager";
    };
    # Other
  };

  outputs = { self, ... }@inputs:
    with self.lib;
    let
      systems = [ "x86_64-linux" "x86_64-darwin" "aarch64-darwin" "aarch64-linux" ];
      foreachSystem = genAttrs systems;
      pkgsBySystem = foreachSystem (
        system:
        import inputs.nixpkgs {
          inherit system;
          config = import ./nix/config.nix;
          overlays = self.overlays."${system}";
          /*overlays = [
            #  self.overlays."${system}"
            inputs.nix-on-droid.overlays.default
            (final: prev: {
              python311Full = prev.python311Full.override {
                packageOverrides = finalPkgs: prevPkgs: {
                  # Disable failing tests https://github.com/NixOS/nixpkgs/issues/272430
                  eventlet = prevPkgs.eventlet.overridePythonAttrs (prevAttrs: {
                    disabledTests = prevAttrs.disabledTests ++ [
                      "test_full_duplex"
                    ];
                  });
                };
              };
            })
          ];
          */
        }
      );
    in
    rec {
      lib = import ./lib { inherit self inputs config; } // inputs.nixpkgs.lib;

      devShell = foreachSystem (system: import ./shell.nix { pkgs = pkgsBySystem."${system}"; });

      legacyPackages = pkgsBySystem;
      packages = foreachSystem (system: import ./nix/pkgs self system);
      overlay = foreachSystem (system: _final: _prev: self.packages."${system}");
      overlays = foreachSystem (
        system: with inputs; let
          ovs = attrValues (import ./nix/overlays self);
        in
        [
          (self.overlay."${system}")
          (nur.overlay)
          # (_:_: { inherit (eww.packages."${system}") eww; })
        ] ++ ovs
      );

      nixOnDroidConfigurations = mapAttrs' mkNixOnDroidConfiguration {
        nix-on-droid = { user = "droid"; };
        default = { user = "droid"; };
      };

      homeConfigurations = mapAttrs' mkHome {
        L242731 = { user = "mdavis67"; system = "x86_64-linux"; };
      };

      darwinConfigurations = mapAttrs' mkNixSystemConfiguration {
        mwdavis-workm1 = { system = "aarch64-darwin"; user = "mwdavisii"; buildTarget = "darwin"; }; #macbook
	      L211011 = { system = "aarch64-darwin"; user = "mdavis67"; buildTarget = "darwin"; };
        L241729 = { system = "aarch64-darwin"; user = "mdavis67"; buildTarget = "darwin"; };
      };

      nixosConfigurations = mapAttrs' mkNixSystemConfiguration {
        athena = { hostname = "athena"; user = "mwdavisii"; buildTarget = "nixos"; };
        ares = { user = "nixos"; hostname = "ares"; buildTarget = "nixos"; }; #WSL
        asahi = { user = "mwdavisii"; system = "aarch64-darwin"; hostname = "asahi"; buildTarget = "nixos"; }; #WSL
        hephaestus = { hostname = "hephaestus"; user = "mwdavisii"; buildTarget = "nixos"; }; #home machine
        livecd = { hostname = "worklt"; user = "mwdavisii"; buildTarget = "iso"; }; #nix build .#nixosConfigurations.livecd.config.system.build.isoImage
        mwdavis-workm1 = { system = "aarch64-darwin"; user = "mwdavisii"; buildTarget = "darwin"; }; #macbook
        nixos = { user = "nixos"; hostname = "nixos"; buildTarget = "nixos"; }; #WSL
        olenos = { hostname = "olenos"; user = "mwdavisii"; buildTarget = "nixos"; }; #Work Laptop (Host OS)
        virtualbox = { hostname = "virtualBoxOVA"; user = "mwdavisii"; buildTarget = "vm"; }; #nix build .#nixosConfigurations.virtualbox.config.system.build.isoImage
        L211011 = { system = "aarch64-darwin"; user = "mdavis67"; buildTarget = "darwin"; };
        L241729 = { system = "aarch64-darwin"; user = "mdavis67"; buildTarget = "darwin"; };
      };

      top =
        let
          livecd = (builtins.attrNames inputs.self.nixosConfigurations)
            #(attr: inputs.self.nixosConfigurations.${attr}.config.system.build.isoImage);
            (attr: inputs.self.nixosConfigurations.${attr}.livecd.config.formats.iso);
          droidtop = genAttrs
            (builtins.attrNames inputs.self.nixOnDroidConfigurations)
            (attr: inputs.self.nixOnDroidConfigurations.${attr}.config.system.build.toplevel);
          nixtop = genAttrs
            (builtins.attrNames inputs.self.nixosConfigurations)
            (attr: inputs.self.nixosConfigurations.${attr}.config.system.build.toplevel);
          hometop = genAttrs
            (builtins.attrNames inputs.self.homeManagerConfigurations)
            (attr: inputs.self.homeManagerConfigurations.${attr}.activationPackage);
          darwintop = genAttrs
            (builtins.attrNames inputs.self.darwinConfigurations)
            (attr: inputs.self.darwinConfigurations.${attr}.system);
          vmtop = genAttrs
            (builtins.attrNames inputs.self.nixosConfigurations)
            (attr: inputs.self.nixosConfigurations.${attr}.config.system.build.toplevel);
        in
        droidtop // nixtop // hometop // darwintop // vmtop;
    };
}
