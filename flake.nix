{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    qwerty-fr = {
        url = "github:qwerty-fr/qwerty-fr";
        flake = false;
    };
    mangowm = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    noctalia.url = "github:noctalia-dev/noctalia/cachix";
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, home-manager, mangowm, noctalia, zen-browser, ... }@inputs:
  let
    mkHost = hostPath: homeModule: nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      specialArgs = { inherit inputs; };
      modules = [
        hostPath
        mangowm.nixosModules.mango
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
