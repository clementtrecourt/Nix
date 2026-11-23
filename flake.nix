{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    # <-- 1. Chaotic-Nyx (pour le PC Home)
    chaotic.url = "https://flakehub.com/f/chaotic-cx/nyx/*.tar.gz";

    # <-- 2. MicroVM (pour le PC Work)
    microvm = {
      url = "github:astro/microvm.nix";
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
    lazyvim = {
      url = "github:pfassina/lazyvim-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    zen-browser = {
      url = "github:0xc000022070/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    spotx-nix = {
      url = "github:SpotX-Official/SpotX-Nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    qwerty-fr = {
      url = "github:qwerty-fr/qwerty-fr";
      flake = false;
    };

    # Icônes d'apps macOS 26 Tahoe (PNG 1024 exportés d'un Mac) : jamais copiées
    # dans le dépôt, uniquement référencées ici (thème MacTahoe-Apple, home/macos/pkgs)
    macos-icons = {
      url = "github:zagnut531/macOS-26-Icons/2867e67ae2f12b972fc85e56707bea4b303bdf92";
      flake = false;
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
    helium-flake,
    lazyvim,
    chaotic,
    microvm,
    ...
  } @ inputs: let
    system = "x86_64-linux";
    pkgs = nixpkgs.legacyPackages.${system};

    mkHost = hostPath: homeModule: extraModules:
      nixpkgs.lib.nixosSystem {
        inherit system;
        specialArgs = {inherit inputs;};
        modules =
          [
            hostPath
            nix-index-database.nixosModules.nix-index

            {
              nixpkgs.overlays = [
                inputs.spotx-nix.overlays.default
                inputs.helium-flake.overlays.default
              ];
            }

            home-manager.nixosModules.home-manager
            {
              home-manager.useGlobalPkgs = true;
              home-manager.useUserPackages = true;
              home-manager.backupFileExtension = "bak";
              home-manager.users.clem = import homeModule;
              home-manager.extraSpecialArgs = {inherit inputs;};
            }
          ]
          ++ extraModules; # <-- Permet d'ajouter des modules spécifiques par machine
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
      # Machine Home avec Chaotic-Nyx
      home = mkHost ./hosts/home/configuration.nix ./home/home.nix [
        chaotic.nixosModules.default
      ];

      # Machine Work avec MicroVM
      work = mkHost ./hosts/work/configuration.nix ./home/work.nix [
        microvm.nixosModules.host
      ];
    };
  };
}
