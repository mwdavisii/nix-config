{ config, inputs, lib, pkgs, ... }:

with lib;
let
  cfg = config.nyx.profiles.work;
in
{
  options.nyx.profiles.work = {
    enable = mkEnableOption "work profile";
  };

  config = mkIf cfg.enable {
    fonts = {
      fonts = with pkgs; [
        (
          nerdfonts.override {
            fonts = [ "JetBrainsMono" "Hack" "Meslo" "UbuntuMono" ];
          }
        )
      ];
    };
  };
}
