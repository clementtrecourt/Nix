{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    oskars-dotfiles = {
      url = "github:oskardotglobal/.dotfiles/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    qwerty-fr = {
        url = "github:qwerty-fr/qwerty-fr";
        flake = false;
    };
    hyprland.url = "github:hyprwm/Hyprland";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    gloview = {
      url = "github:fedsfarm/gloview";
      inputs.hyprland.follows = "hyprland";
    };
    caelestia-shell = {
      url = "github:caelestia-dots/shell";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    caelestia-cli = {
      url = "github:caelestia-dots/cli";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, oskars-dotfiles, hyprland, zen-browser, ... }@inputs:
  let
    mkHost = hostPath: homeModule: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        hostPath

        {
          nixpkgs.overlays = [
            oskars-dotfiles.overlays.spotx
          ];
        }

        {
    virtualisation.podman = {
      enable = true;
      dockerCompat = true;
    };
  }

        hyprland.nixosModules.default
        ./modules/hyprland.nix

        home-manager.nixosModules.home-manager

        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "bak";
          home-manager.users.clem = import homeModule;
          home-manager.extraSpecialArgs = { inherit inputs; };
        }
      ];

    };
  in
  {
    nixosConfigurations = {
      home = mkHost ./hosts/home/configuration.nix ./home/common.nix;
      work = mkHost ./hosts/work/configuration.nix ./home/work.nix;
    };
  };
}
