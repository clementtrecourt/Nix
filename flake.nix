{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nix-index-database = {
      url = "github:nix-community/nix-index-database";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mango = {
      url = "github:mangowm/mango";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
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

  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-index-database,
    oskars-dotfiles,
    helium-flake,
    mango,
    lazyvim,
    sops-nix,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system}; # <-- Ligne ajoutée ici

    mkHost = hostPath: homeModule:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules = [
          hostPath
          nix-index-database.nixosModules.nix-index
          sops-nix.nixosModules.sops

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
            home-manager.extraSpecialArgs = {inherit inputs;};
            home-manager.sharedModules = [
              mango.hmModules.mango
            ];
          }
        ];
      };
  in {
    formatter.${system} = pkgs.writeShellScriptBin "nix-fmt" ''
      if [ "$#" -eq 0 ]; then
        exec ${pkgs.alejandra}/bin/alejandra .
      else
        exec ${pkgs.alejandra}/bin/alejandra "$@"
      fi
    '';

    nixosConfigurations = {
      home = mkHost ./hosts/home/configuration.nix ./home/common.nix;
      work = mkHost ./hosts/work/configuration.nix ./home/work.nix;
    };
  };
}
