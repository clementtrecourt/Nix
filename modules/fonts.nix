# Typographie système : famille Apple partout, quel que soit le toolkit.
#
#   sans-serif  -> SF Pro Text  (bascule auto sur SF Pro Display à partir de 20 pt)
#   serif       -> New York     (Small / Medium / Large / ExtraLarge selon la taille)
#   monospace   -> SF Mono      (variante Nerd Font : icônes de prompt incluses)
#   emoji       -> Apple Color Emoji
#   repli       -> Noto (CJK, scripts rares), Symbols Nerd Font (icônes)
#
# Rendu selon la densité de l'écran (my.display, cf. modules/display.nix) :
#   - basse densité (24" 1080p ~92 ppp) : le lissage gris façon macOS y est flou ;
#     sous-pixel + hinting léger donnent un texte net ;
#   - HiDPI (échelle >= 1.5) : niveaux de gris sans hinting, comme macOS (le
#     sous-pixel n'apporte rien et colore les bords une fois mis à l'échelle).
# Dans les deux cas, traits épaissis (stem darkening FreeType) : texte "plein".
{
  config,
  pkgs,
  ...
}: let
  display = config.my.display;
  appleFonts = pkgs.callPackage ../pkgs/apple-fonts.nix {};

  # <match> qui remplace une famille demandée par une autre, sans repli possible
  replace = from: to: ''
    <match target="pattern">
      <test qual="any" name="family"><string>${from}</string></test>
      <edit name="family" mode="assign" binding="strong"><string>${to}</string></edit>
    </match>
  '';
  replaceAll = to: froms: builtins.concatStringsSep "" (map (f: replace f to) froms);

  # Taille optique : une famille "texte" devient sa version "titre" au-delà d'un seuil (en points)
  opticalSize = from: to: minPt: ''
    <match target="pattern">
      <test name="family"><string>${from}</string></test>
      <test name="size" compare="more_eq"><double>${toString minPt}</double></test>
      <edit name="family" mode="assign" binding="same"><string>${to}</string></edit>
    </match>
  '';
in {
  fonts = {
    # Pas de DejaVu / FreeFont / Unifont / Noto Emoji : ils "gagnent" sinon des
    # replis et cassent l'homogénéité. La couverture vient de Noto, ajouté en dernier.
    enableDefaultPackages = false;

    packages = with pkgs; [
      appleFonts.sf-pro
      appleFonts.sf-mono
      appleFonts.new-york
      appleFonts.apple-emoji

      # Repli : alphabets non latins, CJK, symboles
      noto-fonts
      noto-fonts-cjk-sans
      noto-fonts-cjk-serif
      nerd-fonts.symbols-only
    ];

    fontconfig = {
      enable = true;
      antialias = true;
      hinting = {
        enable = !display.hidpi;
        style = "slight";
      };
      subpixel = {
        rgba =
          if display.hidpi
          then "none"
          else display.subpixelOrder;
        lcdfilter = "default";
      };

      defaultFonts = {
        # Apple Color Emoji juste après la police principale : sinon un 😀 dans du
        # texte prend le premier repli qui a le glyphe (emoji monochrome moche).
        sansSerif = ["SF Pro Text" "Apple Color Emoji" "Noto Sans" "Noto Sans CJK SC" "Symbols Nerd Font"];
        serif = ["New York Small" "Apple Color Emoji" "Noto Serif" "Noto Serif CJK SC"];
        monospace = ["SF Mono" "Apple Color Emoji" "Noto Sans Mono" "Noto Sans Mono CJK SC" "Symbols Nerd Font Mono"];
        emoji = ["Apple Color Emoji"];
      };

      localConf = ''
        <?xml version="1.0"?>
        <!DOCTYPE fontconfig SYSTEM "fonts.dtd">
        <fontconfig>
          <!-- Polices "système" demandées par les sites web, Electron, GTK, Qt... -->
          ${replaceAll "SF Pro Text" [
          "system-ui"
          "ui-sans-serif"
          "-apple-system"
          "BlinkMacSystemFont"
          ".AppleSystemUIFont"
          "San Francisco"
          "SF Pro"
          "Helvetica"
          "Helvetica Neue"
          "Arial"
          "Liberation Sans"
          "Segoe UI"
          "Segoe UI Variable"
          "Roboto"
          "Inter"
          "Open Sans"
          "Noto Sans UI"
          "Ubuntu"
          "Cantarell"
          "Adwaita Sans"
          "DejaVu Sans"
          "Verdana"
          "Tahoma"
          "Calibri"
          "Lucida Grande"
        ]}
          ${replaceAll "SF Pro Rounded" ["ui-rounded"]}
          ${replaceAll "New York Small" [
          "ui-serif"
          "Times"
          "Times New Roman"
          "Liberation Serif"
          "Georgia"
          "Cambria"
          "DejaVu Serif"
          "Noto Serif Display"
        ]}
          ${replaceAll "SF Mono" [
          "ui-monospace"
          "SFMono-Regular"
          "Menlo"
          "Monaco"
          "Courier"
          "Courier New"
          "Liberation Mono"
          "Consolas"
          "Cascadia Code"
          "Cascadia Mono"
          "DejaVu Sans Mono"
          "Ubuntu Mono"
          "Adwaita Mono"
          "JetBrains Mono"
          "Fira Code"
          "Fira Mono"
          "Source Code Pro"
        ]}
          ${replaceAll "Apple Color Emoji" [
          "emoji"
          "Noto Color Emoji"
          "Noto Emoji"
          "Segoe UI Emoji"
          "Segoe UI Symbol"
          "Twemoji"
          "Twemoji Mozilla"
          "EmojiOne Color"
          "JoyPixels"
        ]}

          <!-- Tailles optiques, comme sur macOS -->
          ${opticalSize "SF Pro Text" "SF Pro Display" 20}
          ${opticalSize "New York Small" "New York Medium" 20}
          ${opticalSize "New York Medium" "New York Large" 35}
          ${opticalSize "New York Large" "New York ExtraLarge" 60}

          <!-- DejaVu (dernier recours imposé par NixOS) : jamais affiché, Noto couvre -->
          <selectfont>
            <rejectfont>
              <pattern><patelt name="family"><string>DejaVu Sans</string></patelt></pattern>
              <pattern><patelt name="family"><string>DejaVu Serif</string></patelt></pattern>
              <pattern><patelt name="family"><string>DejaVu Sans Mono</string></patelt></pattern>
            </rejectfont>
          </selectfont>

          <!-- Les emoji couleur ne doivent jamais être lissés en sous-pixel -->
          <match target="font">
            <test name="family"><string>Apple Color Emoji</string></test>
            <edit name="rgba" mode="assign"><const>none</const></edit>
            <edit name="hinting" mode="assign"><bool>false</bool></edit>
          </match>

          <!-- Pas de version bitmap/synthétique des polices CFF Apple -->
          <match target="font">
            <test name="fontformat"><string>CFF</string></test>
            <edit name="embeddedbitmap" mode="assign"><bool>false</bool></edit>
          </match>
        </fontconfig>
      '';
    };
  };

  # Traits plus pleins (rendu proche de macOS) pour les polices CFF/OTF et l'autohinter
  environment.sessionVariables.FREETYPE_PROPERTIES = "cff:no-stem-darkening=0 autofitter:no-stem-darkening=0";

  # TTY / greeter : Terminus, la police console la plus propre, taille selon la densité
  console = {
    earlySetup = true;
    packages = [pkgs.terminus_font];
    font =
      if display.hidpi
      then "ter-v32n"
      else "ter-v20n";
  };
}
