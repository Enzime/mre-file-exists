{
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/bc947f541ae55e999ffdb4013441347d83b00feb";
  inputs.disko.url = "github:nix-community/disko";
  inputs.disko.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixos-anywhere.url = "github:nix-community/nixos-anywhere";
  inputs.nixos-anywhere.inputs.disko.follows = "disko";
  inputs.nixos-anywhere.inputs.nixpkgs.follows = "nixpkgs";
  inputs.nixos-anywhere.inputs.nixos-stable.follows = "";
  inputs.nixos-anywhere.inputs.treefmt-nix.follows = "";

  inputs.nix-darwin.url = "github:LnL7/nix-darwin";
  inputs.nix-darwin.inputs.nixpkgs.follows = "nixpkgs";

  inputs.nixpkgs-other.url = "github:NixOS/nixpkgs/ad416d066ca1222956472ab7d0555a6946746a80";

  outputs = { self, nixpkgs, disko, nixos-anywhere, nix-darwin, nixpkgs-other, ... }: {
    nixosConfigurations.hermes-macos-aarch64-linux-vm = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        disko.nixosModules.disko
        ({ pkgs, ... }:

        {
          imports = [ ./hardware-configuration.nix ];

          boot.loader.systemd-boot.enable = true;
          boot.loader.efi.canTouchEfiVariables = true;

          nix.package = pkgs.nixVersions.latest;
          networking.hostName = "hermes-macos-aarch64-linux-vm";

          services.openssh.enable = true;

          services.tailscale.enable = true;

          nix.settings.experimental-features = "nix-command flakes";

          users.users = let
            sshKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINKZfejb9htpSB5K9p0RuEowErkba2BMKaze93ZVkQIE";
          in {
            enzime = {
              isNormalUser = true;
              extraGroups = [ "wheel" ];
              password = "apple";
              openssh.authorizedKeys.keys = [ sshKey ];
            };

            root.openssh.authorizedKeys.keys = [ sshKey ];
          };

          disko.devices = {
            disk.primary = {
              type = "disk";
              device = "/dev/vda";
              content = {
                type = "gpt";

                partitions.esp = {
                  size = "500M";
                  type = "EF00";
                  content = {
                    type = "filesystem";
                    format = "vfat";
                    mountpoint = "/boot";
                  };
                };

                partitions.root = {
                  size = "100%";
                  content = {
                    type = "filesystem";
                    format = "ext4";
                    mountpoint = "/";
                  };
                };
              };
            };
          };

          system.stateVersion = "24.11";
        })
      ];
    };

    darwinConfigurations.hermes-macos-aarch64-darwin-vm = nix-darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      modules = [
        ({ pkgs, ... }:

        {
          networking.hostName = "hermes-macos-aarch64-darwin-vm";

          services.nix-daemon.enable = true;
          nix.package = pkgs.nixVersions.latest;

          nix.settings.experimental-features = "nix-command flakes";

          programs.zsh.enable = true;

          system.configurationRevision = self.rev or self.dirtyRev or null;

          services.tailscale.enable = true;

          users.users.admin.openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINKZfejb9htpSB5K9p0RuEowErkba2BMKaze93ZVkQIE" ];

          system.stateVersion = 5;

          nixpkgs.hostPlatform = "aarch64-darwin";
        })
      ];
    };

    packages.x86_64-linux = let
      pkgs = nixpkgs.legacyPackages.x86_64-linux;
    in {
      install-linux = pkgs.writeShellApplication {
        name = "install-linux";
        runtimeInputs = [ nixos-anywhere.packages.${pkgs.system}.nixos-anywhere ];
        text = ''
          nixos-anywhere --flake .#hermes-macos-aarch64-linux-vm --generate-hardware-config nixos-generate-config hardware-configuration.nix --build-on-remote "$@"
        '';
      };
      deploy-linux = pkgs.writeShellApplication {
        name = "deploy-linux";
        runtimeInputs = [ pkgs.nixos-rebuild ];
        text = ''
          nixos-rebuild switch --fast --flake .#hermes-macos-aarch64-linux-vm --substitute-on-destination --build-host root@hermes-macos-aarch64-linux-vm --target-host root@hermes-macos-aarch64-linux-vm
        '';
      };
      deploy-macos = pkgs.writeShellApplication {
        name = "deploy-macos";
        text = ''
          nix copy --to ssh-ng://admin@hermes-macos-aarch64-darwin-vm ${./.}
          ssh -t admin@hermes-macos-aarch64-darwin-vm darwin-rebuild switch --flake ${./.}
        '';
      };
    };

    packages.aarch64-linux = let
      pkgs = nixpkgs-other.legacyPackages.aarch64-linux;
    in {
      default = pkgs.buildEnv {
        name = "mre";
        paths = [ pkgs.alacritty.terminfo pkgs.ncurses ];
        ignoreCollisions = true;
        pathsToLink = [ "/share/terminfo" ];
      };
    };
  };
}
