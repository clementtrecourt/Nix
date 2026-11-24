# Famille typographique Apple, depuis des miroirs GitHub figés sur un commit :
#   sf-pro      : SF Pro Text (interface), SF Pro Display (titres), SF Pro Rounded
#   sf-mono     : SF Mono patché Nerd Font (terminal, éditeur, icônes de prompt)
#   new-york    : New York Small / Medium / Large / ExtraLarge (serif)
#   apple-emoji : Apple Color Emoji (macOS 26)
#
# Licences Apple : usage personnel uniquement, ne jamais pousser ces paquets
# sur un cache public.
#
# Usage : appleFonts = pkgs.callPackage ../pkgs/apple-fonts.nix {};
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
  fetchurl,
}: let
  mkFont = {
    pname,
    src,
    install,
    description,
    homepage,
    dontUnpack ? false,
  }:
    stdenvNoCC.mkDerivation {
      inherit pname src dontUnpack;
      version = "0-unstable";
      installPhase = ''
        runHook preInstall
        ${install}
        runHook postInstall
      '';
      meta = {
        inherit description homepage;
        license = lib.licenses.unfree;
        platforms = lib.platforms.all;
      };
    };
in {
  sf-pro = mkFont {
    pname = "sf-pro";
    src = fetchFromGitHub {
      owner = "sahibjotsaggu";
      repo = "San-Francisco-Pro-Fonts";
      rev = "8bfea09aa6f1139479f80358b2e1e5c6dc991a58";
      hash = "sha256-mAXExj8n8gFHq19HfGy4UOJYKVGPYgarGd/04kUIqX4=";
    };
    # OTF statiques uniquement : la version variable (SF-Pro.ttf) doublonnerait
    # les familles et donnerait des graisses aléatoires dans Qt.
    install = "install -Dm644 -t $out/share/fonts/opentype *.otf";
    description = "Apple SF Pro Text / Display / Rounded";
    homepage = "https://github.com/sahibjotsaggu/San-Francisco-Pro-Fonts";
  };

  sf-mono = mkFont {
    pname = "sf-mono-nerd-font";
    src = fetchFromGitHub {
      owner = "epk";
      repo = "SF-Mono-Nerd-Font";
      rev = "ebd4255167f1b9105cfdf5694ea9a474f08a51c3";
      hash = "sha256-h2u3s8jU4IKtQ1fZKRVjR+BvYjGZ9n0QDXkddcRB1u4=";
    };
    # Familles exposées : "SF Mono" et "SFMono Nerd Font"
    install = "install -Dm644 -t $out/share/fonts/opentype *.otf";
    description = "Apple SF Mono avec glyphes Nerd Font";
    homepage = "https://github.com/epk/SF-Mono-Nerd-Font";
  };

  new-york = mkFont {
    pname = "new-york";
    src = fetchFromGitHub {
      owner = "yell0wsuit";
      repo = "New-York-fonts";
      rev = "3d6c984cd62c30aac47708b4bdce36a08fc723f1";
      hash = "sha256-0uuzr64KxDEMtkLizvGeHTXDBAMLe4j5iXGaJPfDdmg=";
    };
    install = "install -Dm644 -t $out/share/fonts/opentype *.otf";
    description = "Apple New York (serif, tailles optiques Small à ExtraLarge)";
    homepage = "https://github.com/yell0wsuit/New-York-fonts";
  };

  apple-emoji = mkFont {
    pname = "apple-color-emoji";
    src = fetchurl {
      url = "https://github.com/samuelngs/apple-emoji-ttf/releases/download/macos-26-20260722-484daf4e/AppleColorEmoji-Linux.ttf";
      hash = "sha256-43x69iZaxKCvbVe8ZehhCad22ZZug0MzRVf2PaSCUW8=";
    };
    dontUnpack = true;
    install = "install -Dm644 $src $out/share/fonts/truetype/AppleColorEmoji.ttf";
    description = "Apple Color Emoji (macOS 26)";
    homepage = "https://github.com/samuelngs/apple-emoji-ttf";
  };
}
