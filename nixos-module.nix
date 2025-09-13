{ config, pkgs, lib, ... }:

let
  # The mcreator package provided by the flake
  mcreator = import ../flake.nix { inherit pkgs; }.packages.x86_64-linux.mcreator;
in
{
  options = {
    # Option to enable or disable MCreator installation
    mcreator.enable = lib.mkEnableOption "MCreator";
  };

  config = lib.mkIf config.mcreator.enable {
    # Adding MCreator to systemPackages if enabled
    environment.systemPackages = [ mcreator ];
  };
}
