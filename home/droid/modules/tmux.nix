{ config, lib, pkgs, ... }:

{
  programs.tmux = {
    enable = true;
    aggressiveResize = true;
    baseIndex = 1;
    clock24 = true;
    disableConfirmationPrompt = true; 
    keyMode = "vi";
    prefix = "C-a";
    terminal = "screen-256color";
    plugins = with pkgs.tmuxPlugins; [
      copycat
      extrakto
      fuzzback
      nord
      prefix-highlight
      tmux-fzf
      vim-tmux-navigator
    ];
    extraConfig = ''
      set -g detach-on-destroy off             # When destory switch to the prev session
      set -ga terminal-overrides ",*256col*:Tc"
      set -g default-shell $SHELL              # use default shell
      set -sg escape-time 5                    # delay shorter
      set -sg history-limit 50000              # increase scrollback
      set -g mouse on                          # enable mouse mode

      source-file ~/.config/tmux/conf/keybindings.conf

      # left status is only length of 10
      set -g status-left-length 50
    '';
  };

  xdg.configFile."tmux/scripts" = {
    source = ../../config/.config/tmux/scripts;
    recursive = true;
    executable = true;
  };
  xdg.configFile."tmux/conf" = {
    source = ../../config/.config/tmux/conf;
    recursive = true;
    executable = true;
  };
}
