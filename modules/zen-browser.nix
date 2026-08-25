{
  inputs,
  pkgs,
  lib,
  ...
}:
let
  extension = shortId: guid: {
    name = guid;
    value = {
      install_url = "https://addons.mozilla.org/en-US/firefox/downloads/latest/${shortId}/latest.xpi";
      installation_mode = "normal_installed";
    };
  };

  prefs = {
    # Check these out at about:config
    "extensions.autoDisableScopes" = 0;
    "extensions.pocket.enabled" = false;
    # ...

    ####################################################################
    # BetterZen (Betterfox) v148 — https://github.com/yokoffing/Betterfox
    ####################################################################

    # -- SECUREFOX -------------------------------------------------------
    # Tracking protection
    "browser.contentblocking.category" = "strict";
    "browser.download.start_downloads_in_tmp_dir" = true;
    "browser.uitour.enabled" = false;
    "privacy.globalprivacycontrol.enabled" = true;

    # OCSP & certs / HPKP
    "security.OCSP.enabled" = 0;
    "privacy.antitracking.isolateContentScriptResources" = true;
    "security.csp.reporting.enabled" = false;

    # SSL / TLS
    "security.ssl.treat_unsafe_negotiation_as_broken" = true;
    "browser.xul.error_pages.expert_bad_cert" = true;
    "security.tls.enable_0rtt_data" = false;

    # Disk avoidance
    "browser.cache.disk.enable" = false;
    "browser.privatebrowsing.forceMediaMemoryCache" = true;
    "media.memory_cache_max_size" = 65536;
    "browser.sessionstore.interval" = 60000;

    # Shutdown & sanitizing
    "privacy.history.custom" = true;
    "browser.privatebrowsing.resetPBM.enabled" = true;

    # Speculative loading
    "network.http.speculative-parallel-limit" = 0;
    "network.dns.disablePrefetch" = true;
    "network.dns.disablePrefetchFromHTTPS" = true;
    "browser.urlbar.speculativeConnect.enabled" = false;
    "browser.places.speculativeConnect.enabled" = false;
    "network.prefetch-next" = false;

    # Search / URL bar
    "browser.urlbar.trimHttps" = true;
    "browser.urlbar.untrimOnUserInteraction.featureGate" = true;
    "browser.search.separatePrivateDefault.ui.enabled" = true;
    "browser.search.suggest.enabled" = false;
    "browser.urlbar.quicksuggest.enabled" = false;
    "browser.urlbar.groupLabels.enabled" = false;
    "browser.formfill.enable" = false;
    "network.IDN_show_punycode" = true;

    # HTTPS-only mode
    "dom.security.https_only_mode" = true;
    "dom.security.https_only_mode_error_page_user_suggestions" = true;

    # Passwords
    "signon.formlessCapture.enabled" = false;
    "signon.privateBrowsingCapture.enabled" = false;
    "network.auth.subresource-http-auth-allow" = 1;
    "editor.truncate_user_pastes" = false;

    # Extensions
    "extensions.enabledScopes" = 5;

    # Headers / referers
    "network.http.referer.XOriginTrimmingPolicy" = 2;

    # Containers
    "privacy.userContext.ui.enabled" = true;

    # Various
    "pdfjs.enableScripting" = false;

    # Safe browsing
    "browser.safebrowsing.downloads.remote.enabled" = false;

    # Mozilla
    "permissions.default.desktop-notification" = 2;
    "permissions.default.geo" = 2;
    "geo.provider.network.url" = "https://beacondb.net/v1/geolocate";
    "browser.search.update" = false;
    "permissions.manager.defaultsUrl" = "";
    "extensions.getAddons.cache.enabled" = false;

    # Telemetry
    "datareporting.policy.dataSubmissionEnabled" = false;
    "datareporting.healthreport.uploadEnabled" = false;
    "toolkit.telemetry.unified" = false;
    "toolkit.telemetry.enabled" = false;
    "toolkit.telemetry.server" = "data:,";
    "toolkit.telemetry.archive.enabled" = false;
    "toolkit.telemetry.newProfilePing.enabled" = false;
    "toolkit.telemetry.shutdownPingSender.enabled" = false;
    "toolkit.telemetry.updatePing.enabled" = false;
    "toolkit.telemetry.bhrPing.enabled" = false;
    "toolkit.telemetry.firstShutdownPing.enabled" = false;
    "toolkit.telemetry.coverage.opt-out" = true;
    "toolkit.coverage.opt-out" = true;
    "toolkit.coverage.endpoint.base" = "";
    "browser.newtabpage.activity-stream.feeds.telemetry" = false;
    "browser.newtabpage.activity-stream.telemetry" = false;
    "datareporting.usage.uploadEnabled" = false;

    # Experiments
    "app.shield.optoutstudies.enabled" = false;
    "app.normandy.enabled" = false;
    "app.normandy.api_url" = "";

    # Crash reports
    "breakpad.reportURL" = "";
    "browser.tabs.crashReporting.sendReport" = false;

    # -- PESKYFOX ---------------------------------------------------------
    # Mozilla UI
    "extensions.getAddons.showPane" = false;
    "extensions.htmlaboutaddons.recommendations.enabled" = false;
    "browser.discovery.enabled" = false;
    "browser.shell.checkDefaultBrowser" = false;
    "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.addons" = false;
    "browser.newtabpage.activity-stream.asrouter.userprefs.cfr.features" = false;
    "browser.preferences.moreFromMozilla" = false;
    "browser.aboutConfig.showWarning" = false;
    "browser.startup.homepage_override.mstone" = "ignore";
    "browser.aboutwelcome.enabled" = false;
    "browser.profiles.enabled" = true;

    # Theme adjustments
    "toolkit.legacyUserProfileCustomizations.stylesheets" = true;
    "browser.compactmode.show" = true;
    "browser.privateWindowSeparation.enabled" = false; # Windows only

    # AI
    "browser.ml.enable" = false;
    "browser.ml.chat.enabled" = false;
    "browser.ml.chat.menu" = false;
    "browser.tabs.groups.smart.enabled" = false;
    "browser.ml.linkPreview.enabled" = false;

    # Fullscreen notice
    "full-screen-api.transition-duration.enter" = "0 0";
    "full-screen-api.transition-duration.leave" = "0 0";
    "full-screen-api.warning.timeout" = 0;

    # URL bar
    "browser.urlbar.trending.featureGate" = false;

    # New tab page
    "browser.newtabpage.activity-stream.default.sites" = "";
    "browser.newtabpage.activity-stream.showSponsoredTopSites" = false;
    "browser.newtabpage.activity-stream.feeds.section.topstories" = false;
    "browser.newtabpage.activity-stream.showSponsored" = false;
    "browser.newtabpage.activity-stream.showSponsoredCheckboxes" = false;

    # Downloads
    "browser.download.manager.addToRecentDocs" = false;

    # PDF
    "browser.download.open_pdf_attachments_inline" = true;

    # Tab behavior
    "browser.bookmarks.openInTabClosesMenu" = false;
    "browser.menu.showViewImageInfo" = true;
    "findbar.highlightAll" = true;
    "layout.word_select.eat_space_to_next_word" = false;

    # -- ZEN-SPECIFIC OVERRIDES (disabled upstream; enable if wanted) ----
    # "dom.ipc.processPriorityManager.backgroundUsesEcoQoS" = true;
    # "browser.newtab.preload" = false;
    # "zen.urlbar.show-protections-icon" = true;
    # "media.videocontrols.picture-in-picture.enable-when-switching-tabs.enabled" = false;

    ####################################################################
    # Smoothfox v152 — Natural Smooth Scrolling v3 [MODIFIED]
    # https://github.com/yokoffing/Betterfox — recommended for 120Hz+ displays,
    # largely matches Chrome's Windows Scrolling Personality / Smooth Scrolling.
    ####################################################################
    "apz.overscroll.enabled" = true; # default non-Linux
    "general.smoothScroll" = true; # default
    "general.smoothScroll.msdPhysics.continuousMotionMaxDeltaMS" = 12;
    "general.smoothScroll.msdPhysics.enabled" = true;
    "general.smoothScroll.msdPhysics.motionBeginSpringConstant" = 600;
    "general.smoothScroll.msdPhysics.regularSpringConstant" = 650;
    "general.smoothScroll.msdPhysics.slowdownMinDeltaMS" = 25;
    "general.smoothScroll.msdPhysics.slowdownMinDeltaRatio" = "2";
    "general.smoothScroll.msdPhysics.slowdownSpringConstant" = 250;
    "general.smoothScroll.currentVelocityWeighting" = "1";
    "general.smoothScroll.stopDecelerationWeighting" = "1";
    "mousewheel.default.delta_multiplier_y" = 300; # 250-400; adjust to taste
  };

  extensions = [
    # To add additional extensions, find it on addons.mozilla.org, find
    # the short ID in the url (like https://addons.mozilla.org/en-US/firefox/addon/!SHORT_ID!/)
    # Then go to https://addons.mozilla.org/api/v5/addons/addon/!SHORT_ID!/ to get the guid
    (extension "ublock-origin" "uBlock0@raymondhill.net")
    # ...
  ];

  # Policies shared between the wrapper (extraPolicies) and the system-wide
  # /etc/firefox/policies/policies.json (which Zen actually reads at
  # runtime, since its -appDir points at the unwrapped derivation whose
  # own distribution/policies.json is just `{"policies":{}}`).
  policies = {
    DisableTelemetry = true;
    ExtensionSettings = builtins.listToAttrs extensions;

    # Ship `prefs` through the Enterprise Policies "Preferences" key instead
    # of relying on the wrapper's mozilla.cfg/autoconfig (lockPref), because
    # that mechanism is only read from the *wrapped* derivation's directory,
    # and — same root cause as the policies.json issue — the running process
    # resolves its GRE/appDir to the *unwrapped* derivation, so mozilla.cfg
    # never gets loaded and prefs silently don't apply. The Preferences key
    # goes through /etc/zen/policies/policies.json below, which we've
    # confirmed IS read (about:policies shows Active), so this actually works.
    Preferences = lib.mapAttrs (_name: value: {
      Value = value;
      Status = "locked";
    }) prefs;

    SearchEngines = {
      Default = "ddg";
      Add = [
        {
          Name = "nixpkgs packages";
          URLTemplate = "https://search.nixos.org/packages?query={searchTerms}";
          IconURL = "https://wiki.nixos.org/favicon.ico";
          Alias = "@np";
        }
        {
          Name = "NixOS options";
          URLTemplate = "https://search.nixos.org/options?query={searchTerms}";
          IconURL = "https://wiki.nixos.org/favicon.ico";
          Alias = "@no";
        }
        {
          Name = "NixOS Wiki";
          URLTemplate = "https://wiki.nixos.org/w/index.php?search={searchTerms}";
          IconURL = "https://wiki.nixos.org/favicon.ico";
          Alias = "@nw";
        }
        {
          Name = "noogle";
          URLTemplate = "https://noogle.dev/q?term={searchTerms}";
          IconURL = "https://noogle.dev/favicon.ico";
          Alias = "@ng";
        }
      ];
    };
  };
in
{
  # System-wide policy file — this is what actually fixes "Enterprise
  # Policies service is inactive" AND is now also how `prefs` get applied
  # (via the Preferences key above), since Zen's running binary resolves
  # its distribution/ dir to the *unwrapped* store path (empty policies,
  # and a mozilla.cfg the process never even looks at). MOZ_SYSTEM_POLICIES
  # is compiled in as true, and SysConfD is derived from application.ini's
  # [App] Name — which for this build is "Zen" (Vendor=Mozilla, Name=Zen) —
  # so the path is /etc/zen/policies/policies.json, NOT /etc/firefox/...
  # Confirmed via: grep -i "^Name\|^Vendor" .../zen-bin-*/application.ini
  environment.etc."zen/policies/policies.json".text = builtins.toJSON {
    inherit policies;
  };

  environment.systemPackages = [
    (pkgs.wrapFirefox
      inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.beta-unwrapped
      {
        extraPrefs = lib.concatLines (
          lib.mapAttrsToList (
            name: value: ''lockPref(${lib.strings.toJSON name}, ${lib.strings.toJSON value});''
          ) prefs
        );

        extraPolicies = policies;
      }
    )
  ];
}
