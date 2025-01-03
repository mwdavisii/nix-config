osName=$(uname -s)
hostName=$(uname -n)
userName=$(whoami)

. /etc/os-release
distro=$(echo $ID)

if [[ $osName == "Darwin" ]]; then
  darwin-rebuild --show-trace switch --flake .
elif [[ $userName == "nix-on-droid" ]]; then
  nix-on-droid switch --show-trace --flake .
elif [[ $distro == "ubuntu" ]]; then
  home-manager switch -b backup --show-trace --flake .#$hostName
else
  sudo nixos-rebuild switch --show-trace --flake .#$hostName
  #pkill gpg-agent #force any changes to gpg
fi