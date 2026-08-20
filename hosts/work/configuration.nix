{ config, lib, pkgs, inputs, ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/common.nix
  ];
  services.printing = {
    enable = true;
  };
  boot.kernelPackages = pkgs.linuxPackages;
  programs.firefox = {
  enable = true;
  package = pkgs.librewolf;
  policies = {
    DisableTelemetry = true;
    DisableFirefoxStudies = true;
    Preferences = {
      "browser.theme.content-theme" = 1;
      "browser.theme.toolbar-theme" = 1;
      "cookiebanners.service.mode.privateBrowsing" = 2; # Block cookie banners in private browsing
      "cookiebanners.service.mode" = 2; # Block cookie banners
      "privacy.donottrackheader.enabled" = true;
      "privacy.fingerprintingProtection" = true;
      "privacy.resistFingerprinting" = true;
      "privacy.trackingprotection.emailtracking.enabled" = true;
      "privacy.trackingprotection.enabled" = true;
      "privacy.trackingprotection.fingerprinting.enabled" = true;
      "privacy.trackingprotection.socialtracking.enabled" = true;
    };
    ExtensionSettings = {
      "uBlock0@raymondhill.net" = {
        install_url = "https://addons.mozilla.org/firefox/downloads/latest/ublock-origin/latest.xpi";
        installation_mode = "force_installed";
      };
      "consent-o-matic@cavi.au.dk" = {
          install_url = "https://addons.mozilla.org/firefox/downloads/latest/consent-o-matic/latest.xpi";
          installation_mode = "force_installed";
      };
    };
  };
};

environment.etc."firefox/policies/policies.json".target = "librewolf/policies/policies.json";
  networking.hostName = "nixos-work";
  system.stateVersion = "26.05";
}
