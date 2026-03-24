{
  description = "Minecraft Mod Maker";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    {
      self,
      nixpkgs,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    with builtins;
    with pkgs.lib;
    let
      includePrereleases = false;

      mcreatorReleasesFile = builtins.fetchurl
        "https://api.github.com/repos/MCreator/MCreator/releases?per_page=100";

      asJsonWithPrereleases = fromJSON (readFile mcreatorReleasesFile);
      asJson =
        if includePrereleases then
          asJsonWithPrereleases
        else
          filter (release: !(release.prerelease or false)) asJsonWithPrereleases;

      versionsFromBody =
        body:
        let
          outerRegExpr = ".*<!--\\[\\[(.*)\\]\\]-->";
          matched = match outerRegExpr body;
          minecraftString = (fromJSON (head (throwIf (isNull matched) "" matched))).minecraft;
          innerRegExpr = "([[:alpha:] ]*) ([[:digit:].x/]+)";
          nameVersios = filter (obj: isString obj && stringLength obj > 0) (split ", |and " minecraftString);

          splitAndSwapDot = s: map (replaceStrings [ "." ] [ "_" ]) (strings.splitString "/" s);
          lowerAndSwapSpace = s: replaceStrings [ " " ] [ "_" ] (toLower s);
          toAttrs = listTuple: {
            "${lowerAndSwapSpace (head listTuple)}" = splitAndSwapDot (head (tail listTuple));
          };
        in
        mergeAttrsList (map (s: toAttrs (match innerRegExpr s)) nameVersios);

      formattedJson = filter (v: !(isNull v)) (
        map (
          attr:
          let
            result = tryEval (versionsFromBody attr.body);
          in
          if !result.success then
            null
          else
            {
              mcversion = attr.name;
              support = result.value;
            }
        ) asJson
      );

      baseVersions = lists.unique (concatMap (mcversion: attrNames mcversion.support) formattedJson);

      allVersionsFromBase =
        base:
        filter (v: v != null) (
          lists.unique (lists.flatten (map (mcversion: mcversion.support.${base} or null) formattedJson))
        );

      mcvsSupporting =
        base: version: filter (mcversion: elem version (mcversion.support.${base} or [ ])) formattedJson;

      maxVersion = foldl' (
        mcvA: mcvB: if (compareVersions mcvA.mcversion mcvB.mcversion) == 1 then mcvA else mcvB
      ) { mcversion = "0"; };

      mostUptoDateFor = base: version: maxVersion (mcvsSupporting base version);
      mostUptoDateForgeAny = (maxVersion (map (a: { mcversion = a.name; }) asJson)).mcversion;

      mcreatorFromVersion =
        fullVersion:
        let
          yearMonthVersion = pkgs.lib.lists.take 2 (builtins.splitVersion fullVersion);
          version = builtins.concatStringsSep "." yearMonthVersion;
          versionDash = replaceStrings [ "." ] [ "-" ] version;

          openjfx = pkgs.openjfx21.override { withWebKit = true; };
          jdk = pkgs.javaPackages.compiler.openjdk21.override {
            openjfx21 = openjfx;
            enableJavaFX = true;
          };

          src = fetchTarball {
            url = "https://github.com/MCreator/MCreator/releases/download/${fullVersion}/MCreator.${version}.Linux.64bit.tar.gz";
            sha256 = "12wzngzi8fsyp2lzzrxxy5zmlkri0zdl35z0f0k2r2wfywnjrjc4";
          };

          desktopItem = pkgs.makeDesktopItem {
            name = "MCreator ${version}";
            desktopName = "MCreator ${version}";
            exec = "MCreator${versionDash}";
            terminal = false;
            icon = "mcreator";
            categories = [ "Development" ];
          };

          installPhase = ''
            mkdir -p "$out/share/applications"
            ln -s "${desktopItem}"/share/applications/* "$out/share/applications/"
            mkdir -p "$out/share/icons/hicolor/64x64/apps"
            ln -s "${src}/icon.png" "$out/share/icons/hicolor/64x64/apps/mcreator.png"
          '';
        in
        pkgs.buildFHSEnv {
          name = "MCreator${versionDash}";

          targetPkgs =
            pkgs:
            [
              jdk
              pkgs.freetype
              pkgs.zlib
              pkgs.libGL
              pkgs.gtk3
              pkgs.glib
              pkgs.cairo
              pkgs.pango
              pkgs.atk
              pkgs.gdk-pixbuf
              pkgs.libxi
              pkgs.libx11
              pkgs.libxrandr
              pkgs.libxtst
              pkgs.libxrender
              pkgs.libxxf86vm
              pkgs.libxext
              pkgs.webkitgtk_4_1
            ];

          extraInstallCommands = installPhase;

          runScript = ''
            bash -c "cd ${src} && \
            CLASSPATH=\"${src}/lib/mcreator.jar:${src}/lib/*\" \
            ${jdk}/bin/java \
            --add-opens=java.base/java.lang=ALL-UNNAMED \
            -Djava.library.path=${openjfx}/lib \
            net.mcreator.Launcher"
          '';
        };

      allVersions = lists.unique (map (mcversion: mcversion.mcversion) formattedJson);

      majorVersions = groupBy (substring 0 6) allVersions;

      mcreatorPackagesByMajorVersion = mapAttrs' (
        major: minors:
        let
          newest = foldl' (a: b: if (compareVersions a b) == 1 then a else b) "0" minors;
          pkg = mcreatorFromVersion newest;
        in
        nameValuePair pkg.name pkg
      ) majorVersions;

      mcreatorPackages =
        attrsets.mergeAttrsList (
          flatten (
            map (
              base:
              map (version: {
                ${base + version} = mcreatorFromVersion (mostUptoDateFor base version).mcversion;
              }) (allVersionsFromBase base)
            ) baseVersions
          )
        )
        // {
          default = mcreatorFromVersion mostUptoDateForgeAny;
        }
        // mcreatorPackagesByMajorVersion;

      mcreatorApps = attrsets.mapAttrs (_name: drv: {
        type = "app";
        program = "${drv}/bin/${drv.name}";
      }) mcreatorPackages;

    in
    {
      inherit mcreatorPackagesByMajorVersion;
      packages.${system} = mcreatorPackages;
      apps.${system} = mcreatorApps;
    };
}
