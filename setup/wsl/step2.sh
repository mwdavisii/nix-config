sudo nix-channel --add https://nixos.org/channels/nixos-24.11 nixos
sudo nix-channel --update
nix-shell -p git vim