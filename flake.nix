{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

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
