osName=$(uname -s)
hostName=$(uname -n)
userName=$(whoami)

if [[ $osName == "Darwin" ]]; then
  darwin-rebuild --show-trace switch --flake .
elif [[ $userName == "nix-on-droid" ]]; then
  nix-on-droid switch --show-trace --flake .
else
  sudo nixos-rebuild switch --show-trace --flake .#$hostName
  #pkill gpg-agent #force any changes to gpg
fi
