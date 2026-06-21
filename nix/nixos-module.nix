self:
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.programs.irminsul;
in
{
  options.programs.irminsul = {
    enable = lib.mkEnableOption "irminsul";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.default;
      defaultText = lib.literalExpression "irminsul.packages.\${pkgs.stdenv.hostPlatform.system}.default";
      description = "The irminsul package to use.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];

    security.wrappers.irminsul = {
      owner = "root";
      group = "root";
      capabilities = "cap_net_raw+ep";
      source = lib.getExe cfg.package;
    };
  };
}
