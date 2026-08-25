{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mango.url = "github:mangowm/mango";
    zen-browser = {
        url = "github:0xc000022070/zen-browser-flake";
        inputs.nixpkgs.follows = "nixpkgs";
      };
    lazyvim.url = "github:pfassina/lazyvim-nix";
    oskars-dotfiles = {
      url = "github:oskardotglobal/.dotfiles/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    qwerty-fr = {
      url = "github:qwerty-fr/qwerty-fr";
      flake = false;
    };

    noctalia = {
      url = "github:noctalia-dev/noctalia";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    helium-flake = {
      url = "github:oxcl/nix-flake-helium-browser";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, oskars-dotfiles, helium-flake, mango, lazyvim, ... }@inputs:
  let
    mkHost = hostPath: homeModule: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        hostPath

        {
          nixpkgs.overlays = [
            oskars-dotfiles.overlays.spotx
            helium-flake.overlays.default
          ];
        }

        home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;
          home-manager.backupFileExtension = "bak";
          home-manager.users.clem = import homeModule;
          home-manager.extraSpecialArgs = { inherit inputs; };
          home-manager.sharedModules = [
            mango.hmModules.mango # ou mango.homeManagerModules.default
          ];
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
