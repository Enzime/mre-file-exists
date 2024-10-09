{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/ad416d066ca1222956472ab7d0555a6946746a80";

  outputs = { self, nixpkgs }: let
    pkgs = nixpkgs.legacyPackages.aarch64-linux;
  in {
    packages.aarch64-linux.default = pkgs.buildEnv {
      name = "mre";
      paths = [ pkgs.alacritty.terminfo pkgs.ncurses ];
      ignoreCollisions = true;
      pathsToLink = [ "/share/terminfo" ];
    };
  };
}
