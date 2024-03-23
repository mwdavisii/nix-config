{ config, lib, pkgs, modulesPath, inputs, ... }:

let 
  disko = import inputs ;
in
{

  # This is the disk layout for a dual-boot system with Windows 10.
  disko.devices = {
    disk = {
      nvme0n1 = {
        device = "/dev/sda1";
        type = "disk";
        content = {
          type = "gpt";
          partitions = {
            ESP = {
              type = "EF00";  # EFI partition type.
              size = "500M";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
              };
            };
            root = {
              start = "1M";  # Start immediately after Windows partition.
              size = "100%";  # Takes the remaining half of the disk space.
              content = {
                type = "filesystem";
                format = "ext4";
                mountpoint = "/";
              };
            };
          };
        };
      };
    };
  };
}