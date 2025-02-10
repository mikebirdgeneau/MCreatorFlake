{
  description = "Minecraft Mod Maker";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    mcreator-releases = {
      url = "file+https://api.github.com/repos/MCreator/MCreator/releases?per_page=100";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      mcreator-releases,
    }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in
    with builtins;
    with pkgs.lib;
    let
      includePrereleases = false;

      asJsonWithPrereleases = fromJSON (readFile mcreator-releases);
      asJson =
        if includePrereleases then
          asJsonWithPrereleases
        else
          filter (release: !release.prerelease) asJsonWithPrereleases;

      versionsFromBody =
        body:
        let
          outerRegExpr = ".*<!--\\[\\[(.*)\]\]-->";
          matched = match outerRegExpr body;
          minecraftString = (fromJSON (head (throwIf (isNull matched) "" matched))).minecraft;
          innerRegExpr = "([[:alpha:] ]*) ([[:digit:].x/]+)";
          nameVersios = filter (obj: isString obj && stringLength obj > 0) (split ", |and " minecraftString);

          splitAndSwapDot = (s: map (replaceStrings [ "." ] [ "_" ]) (strings.splitString "/" s));
          lowerAndSwapSpace = s: replaceStrings [ " " ] [ "_" ] (toLower s);
          toAttrs = listTuple: {
            "${lowerAndSwapSpace (head listTuple)}" = splitAndSwapDot (head (tail listTuple));
          };
        in
        mergeAttrsList (map (s: toAttrs (match innerRegExpr s)) nameVersios);

      baseVersions = lists.unique (concatMap (mcversion: attrNames mcversion.support) formattedJson);

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

      allVersionsFromBase =
        base:
        filter (v: v != null) (
          lists.unique (lists.flatten (map (mcversion: mcversion.support.${base} or null) formattedJson))
        );
      mcvsSupporting =
        base: version: (filter (mcversion: elem version (mcversion.support.${base} or [ ])) formattedJson);
      maxVersion = foldl' (
        mcvA: mcvB: if (compareVersions mcvA.mcversion mcvB.mcversion) == 1 then mcvA else mcvB
      ) { mcversion = "0"; };
      mostUptoDateFor = base: version: maxVersion (mcvsSupporting base version);

      mostUptoDateForgeAny = (maxVersion (map (a: { mcversion = a.name; }) asJson)).mcversion;

      mcreatorFromVersion = (
        fullVersion:
        let
          yearMonthVersion = (pkgs.lib.lists.take 2 (builtins.splitVersion fullVersion));
          yearVersionInt = toInt (head yearMonthVersion);
          version = builtins.concatStringsSep "." yearMonthVersion;
          versionDash = replaceStrings [ "." ] [ "-" ] version;

          jdk = if yearVersionInt > 2020 then (pkgs.jdk.override { enableJavaFX = true; }) else pkgs.jdk17;

          src = fetchTarball "https://github.com/MCreator/MCreator/releases/download/${fullVersion}/MCreator.${version}.Linux.64bit.tar.gz";

          installPhase = ''
            mkdir -p "$out/share/applications"
            ln -s "${desktopItem}"/share/applications/* "$out/share/applications/"
            mkdir -p "$out/share/icons/hicolor/64x64/apps"
            ln -s "${src}/icon.png" "$out/share/icons/hicolor/64x64/apps/mcreator.png"
          '';

          desktopItem = pkgs.makeDesktopItem {
            name = "MCreator ${version}";
            desktopName = "MCreator ${version}";
            exec = "MCreator${versionDash}";
            terminal = false;
            icon = "mcreator";
            categories = [ "Development" ];
          };
        in
        (pkgs.buildFHSEnv {
          name = "MCreator${versionDash}";

          targetPkgs =
            pkgs:
            [
              jdk
              pkgs.freetype
              pkgs.zlib
              pkgs.libGL
            ]
            ++ (with pkgs.xorg; [
              libX11
              libXrandr
              libXtst
              libXrender
              libXxf86vm
              libXext
              libXi
            ]);

          extraInstallCommands = installPhase;

          runScript = ''
            bash -c "cd ${src} && \
            CLASSPATH=\"${src}/lib/mcreator.jar:${src}/lib/*\" \
            ${jdk}/bin/java --add-opens=java.base/java.lang=ALL-UNNAMED net.mcreator.Launcher"
          '';
        })
      );

      allVersions = lists.unique (map (mcversion: mcversion.mcversion) formattedJson);
      majorVersions = groupBy (substring 0 6) allVersions;
      mcreatorPackagesByMajorVersion = mapAttrs' (
        major: minors:
        let
          maxVersion = foldl' (mcvA: mcvB: if (compareVersions mcvA mcvB) == 1 then mcvA else mcvB) "0";
          pkg = mcreatorFromVersion (maxVersion minors);
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

      mcreaotrApps = attrsets.mapAttrs (pkgs: drv: {
        type = "app";
        program = "${drv}/bin/${drv.name}";
      }) mcreatorPackages;

    in
    {
      inherit mcreatorPackagesByMajorVersion;
      packages.x86_64-linux = mcreatorPackages;
      apps.x86_64-linux = mcreaotrApps;
    };
}
