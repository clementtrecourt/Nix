# Systancia Gate (ex-IPdiva) : client lancé par le portail web via les liens
# ipdiva://… (RDP, SSH, VNC, VPN). Binaire propriétaire compilé pour Ubuntu 20.04.
#
# Il exige wxWidgets 3.0 (GTK3) et OpenSSL 1.1, tous deux retirés de nixpkgs :
# on reprend ces bibliothèques telles quelles depuis les paquets Ubuntu focal,
# le reste (GTK, curl, appindicator, libtiff, libjpeg…) vient de nixpkgs.
#
# L'archive n'est pas téléchargeable publiquement (portail Gate > Téléchargements)
# et ce dépôt est public : elle n'est PAS versionnée. Une seule fois par machine :
#   nix-store --add-fixed sha256 ~/gateclient_linux_x64.tar.xz
#   nix-store --realise --add-root ~/.local/state/gateclient-src --indirect \
#     "$(nix-store --print-fixed-path sha256 fecfee3e75df5f5ff60dbd2fa2e113871653b7662e1400c4e2484db2243f0a20 gateclient_linux_x64.tar.xz)"
# (la racine GC empêche le nettoyage du store de supprimer l'archive.)
{
  lib,
  stdenv,
  requireFile,
  fetchurl,
  autoPatchelfHook,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  dpkg,
  gtk3,
  glib,
  pango,
  cairo,
  gdk-pixbuf,
  libx11,
  libsm,
  libpng,
  libjpeg8,
  libtiff,
  libnotify,
  curl,
  libappindicator-gtk3,
  openvpn,
  python3,
  freerdp,
  tigervnc,
  xdg-utils,
}: let
  ubuntuDeb = path: hash:
    fetchurl {
      url = "http://archive.ubuntu.com/ubuntu/pool/${path}";
      inherit hash;
    };
in
  stdenv.mkDerivation {
    pname = "gateclient";
    version = "2022-07-07";

    src = requireFile {
      name = "gateclient_linux_x64.tar.xz";
      sha256 = "fecfee3e75df5f5ff60dbd2fa2e113871653b7662e1400c4e2484db2243f0a20";
      message = ''
        L'archive GateClient (Systancia Gate) doit être ajoutée au store à la main :
          nix-store --add-fixed sha256 ~/gateclient_linux_x64.tar.xz
        Voir l'en-tête de pkgs/gateclient/default.nix.
      '';
    };

    debs = [
      (ubuntuDeb "universe/w/wxwidgets3.0/libwxbase3.0-0v5_3.0.4+dfsg-15build1_amd64.deb"
        "sha256-7oDXpUGnbBss/VTQcy4MR/vqhA0d+0PrPDSXFleFXXo=")
      (ubuntuDeb "universe/w/wxwidgets3.0/libwxgtk3.0-gtk3-0v5_3.0.4+dfsg-15build1_amd64.deb"
        "sha256-h0Ba9rqquLr52SHsiA+lZAoCc6trEQxG19AnwA48ra0=")
      (ubuntuDeb "main/o/openssl/libssl1.1_1.1.1f-1ubuntu2_amd64.deb"
        "sha256-Ce4oWIoftWE93GwmqZLVp2kxs88iwCKTDaQTpeWAWZ4=")
    ];

    nativeBuildInputs = [autoPatchelfHook makeWrapper copyDesktopItems dpkg];

    buildInputs = [
      stdenv.cc.cc.lib
      gtk3
      glib
      pango
      cairo
      gdk-pixbuf
      libx11
      libsm
      libpng
      libjpeg8
      libtiff
      libnotify
      curl
      libappindicator-gtk3
    ];

    installPhase = ''
      runHook preInstall

      mkdir -p $out/opt/gateclient $out/lib
      cp -r GateClient img lang $out/opt/gateclient/

      # Seules les bibliothèques réellement utilisées par GateClient (et leurs dépendances).
      for deb in $debs; do dpkg-deb -x "$deb" debs; done
      libdir=debs/usr/lib/x86_64-linux-gnu
      cp -a $libdir/libwx_baseu-3.0.so.0* $libdir/libwx_gtk3u_core-3.0.so.0* \
            $libdir/libwx_gtk3u_adv-3.0.so.0* $libdir/libssl.so.1.1 $libdir/libcrypto.so.1.1 \
            $out/lib/
      # wx 3.0 d'Ubuntu vise libtiff.so.5 ; libtiff.so.6 exporte les mêmes symboles (LIBTIFF_4.0).
      patchelf --replace-needed libtiff.so.5 libtiff.so.6 $out/lib/libwx_gtk3u_core-3.0.so.0.4.0

      install -Dm644 img/gateclient.svg $out/share/icons/hicolor/scalable/apps/gateclient.svg

      # GDK_BACKEND=x11 : wx 3.0 ne sait pas positionner ses fenêtres (bandeau de statut) sous Wayland.
      # SSL_CERT_FILE : l'OpenSSL d'Ubuntu chercherait les certificats dans /usr/lib/ssl.
      makeWrapper $out/opt/gateclient/GateClient $out/bin/gateclient \
        --set-default GDK_BACKEND x11 \
        --set-default SSL_CERT_FILE /etc/ssl/certs/ca-certificates.crt \
        --prefix PATH : ${lib.makeBinPath [openvpn python3 freerdp tigervnc xdg-utils]}

      runHook postInstall
    '';

    # Les liens ipdiva:// du portail ouvrent ce .desktop (cf. xdg.mimeApps dans home/work.nix).
    desktopItems = [
      (makeDesktopItem {
        name = "gateclient";
        desktopName = "GateClient";
        comment = "Client Systancia Gate (ressources du portail ipdiva://)";
        exec = "gateclient %u";
        icon = "gateclient";
        mimeTypes = ["x-scheme-handler/ipdiva"];
        noDisplay = true;
      })
    ];

    meta = {
      description = "Systancia Gate (IPdiva) client";
      homepage = "https://www.systancia.com";
      license = lib.licenses.unfree;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["x86_64-linux"];
      mainProgram = "gateclient";
    };
  }
