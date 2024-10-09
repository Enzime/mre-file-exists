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
            enzime = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINKZfejb9htpSB5K9p0RuEowErkba2BMKaze93ZVkQIE";
            aarch64-darwin-vm = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOpzeF5WYPYAFZgGVbKVMQjErBDoQ77V9T8j7Gwa+hF3";
          in {
            enzime = {
              isNormalUser = true;
              extraGroups = [ "wheel" ];
              password = "apple";
              openssh.authorizedKeys.keys = [
                enzime
                aarch64-darwin-vm
              ];
            };

            root.openssh.authorizedKeys.keys = [ enzime ];
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
          environment.systemPackages = [ pkgs.alacritty.terminfo ];

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

          nix.distributedBuilds = true;

          nix.buildMachines = [{
            protocol = "ssh-ng";
            hostName = "hermes-macos-aarch64-linux-vm";
            sshUser = "enzime";
            sshKey = "/etc/ssh/ssh_host_ed25519_key";
            system = "aarch64-linux";
            supportedFeatures = [ "kvm" "benchmark" "big-parallel" ];
            publicHostKey = "c3NoLWVkMjU1MTkgQUFBQUMzTnphQzFsWkRJMU5URTVBQUFBSUgxVzluZU1xNFJWNTljSVMrTVNOSzU5QmJkcE5iaWo1d2lweVNVQThka3kgcm9vdEBoZXJtZXMtbWFjb3MtYWFyY2g2NC1saW51eC12bQo=";
          }];
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
      build-package = pkgs.writeShellApplication {
        name = "build-package";
        text = ''
          nix copy --to ssh-ng://admin@hermes-macos-aarch64-darwin-vm ${./.}
          ssh -t admin@hermes-macos-aarch64-darwin-vm nix build --print-build-logs ${./.}#packages.aarch64-linux.default
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
