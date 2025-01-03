{ ... }:
{
  home.stateVersion = "24.05";
  # Manage home-manager with home-manager (inception)
  programs.home-manager.enable = true;
  # Install man output for any Nix packages.
  programs.man.enable = true;

  manual.manpages.enable = true;

  nyx = {
    modules = {
      dev = {
        cc.enable = true;
        rust.enable = true;
        go.enable = true;
        dhall.enable = true;
        lua.enable = true;
        nix.enable = true;
        node.enable = true;
        python.enable = true;
      };
      shell = {
        awscliv2.enable = true;
        azurecli.enable = true;
        bash.enable = true;
        bat.enable = true;
        direnv.enable = true;
        eza.enable = true;
        fzf.enable = true;
        gcp.enable = true;
        git = {
          enable = true;
          signing.signByDefault = false;
        };
        gnupg = {
          enable = true;
          enableService = true;
        };
        jq.enable = true;
        k8sTooling.enable = true;
        lf.enable = true;
        lorri.enable = false;
        mcfly.enable = true;
        neovim.enable = true;
        networking.enable = true;
        starship.enable = true;
        terraform.enable = true;
        tmux.enable = true;
        usbutils.enable = true;
        xdg.enable = true;
        zellij.enable = true;
        zsh.enable = true;
      };
    };
  };
}