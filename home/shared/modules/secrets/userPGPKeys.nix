{ config, lib, pkgs, userConf, agenix, secrets, ... }:
with lib;
let  
    cfg = config.nyx.modules.secrets.userPGPKeys;
    homePath = if pkgs.stdenv.isDarwin then "/Users/${userConf.userName}" else "/home/${userConf.userName}";
in
{
    options.nyx.modules.secrets.userPGPKeys = {
        enable = mkEnableOption "Enable User GPG Key Decryption";
    };

    config = mkIf cfg.enable {
        age.secrets.gnugp_public_key = {
            symlink = true;
            file = "${secrets}/encrypted/gnugp_public_key.age";
            mode = "400";
            path =  "${homePath}/.for-import/gnugp_public.key";
            #owner = "${userConf.userName}";
        };

        age.secrets.gnugp_private_key = {
            symlink = true;
            file = "${secrets}/encrypted/gnugp_private_key.age";
            mode = "400";
            path =  "${homePath}/.for-import/gnugp_private.key";
            #owner = "${userConf.userName}";
        };
        
    };
}