{
  description = "Minecraft Mod Maker";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    mcreator-releases = {
      url = "file+https://api.github.com/repos/MCreator/MCreator/releases";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, mcreator-releases }:
    let
      system = "x86_64-linux";
      pkgs = nixpkgs.legacyPackages.${system};
    in with builtins;
    with pkgs.lib;
    let
      baseVersions = [ "forge" "datapack" "bedrock" ];
      includePrereleases = false;

      asJsonWithPrereleases = fromJSON (readFile mcreator-releases);
      asJson = if includePrereleases then
        asJsonWithPrereleases
      else
        filter (release: !release.prerelease) asJsonWithPrereleases;
      regExpr =
        ".*?Minecraft Forge ([[:digit:].x/]*), Data Packs ([[:digit:].x/]*), and Bedrock Edition ([[:digit:].x/]*).*?$";
      versionsFromBody = match regExpr;
      toSupportedVersion = mcversions:
        listToAttrs (lists.zipListsWith (base: mcversion: {
          name = base;
          value = mcversion;
        }) baseVersions mcversions);
      splitAndSwapDot = xs:
        map
        (s: map (replaceStrings [ "." ] [ "_" ]) (strings.splitString "/" s))
        xs;
      formattedJson = map (attr: {
        mcversion = attr.name;
        support =
          toSupportedVersion (splitAndSwapDot (versionsFromBody attr.body));
      }) asJson;
      allVersionsFromBase = base:
        lists.unique (lists.flatten
          (map (mcversion: mcversion.support.${base}) formattedJson));
      mcvsSupporting = base: version:
        (filter (mcversion: elem version mcversion.support.${base})
          formattedJson);
      maxVersion = foldl' (mcvA: mcvB:
        if (compareVersions mcvA.mcversion mcvB.mcversion) == 1 then
          mcvA
        else
          mcvB) { mcversion = "0"; };
      mostUptoDateFor = base: version: maxVersion (mcvsSupporting base version);

      mostUptoDateForgeAny =
        (maxVersion (map (a: { mcversion = a.name; }) asJson)).mcversion;

      mcreatorFromVersion = (fullVersion:
        let
          jdk = pkgs.jdk17;

          version = builtins.concatStringsSep "."
            (pkgs.lib.lists.take 2 (builtins.splitVersion fullVersion));
          versionDash = replaceStrings [ "." ] [ "-" ] version;

          src = fetchTarball
            "https://github.com/MCreator/MCreator/releases/download/${fullVersion}/MCreator.${version}.Linux.64bit.tar.gz";

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
        in (pkgs.buildFHSEnv {
          name = "MCreator${versionDash}";

          targetPkgs = pkgs:
            [ jdk pkgs.freetype pkgs.zlib pkgs.libGL ] ++ (with pkgs.xorg; [
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
        }));

      mcreatorPackages = attrsets.mergeAttrsList (flatten (map (base:
        map (version: {
          ${base + version} =
            mcreatorFromVersion (mostUptoDateFor base version).mcversion;
        }) (allVersionsFromBase base)) baseVersions)) // {
          default = mcreatorFromVersion mostUptoDateForgeAny;
        };

      mcreaotrApps = attrsets.mapAttrs (pkgs: drv: {
        type = "app";
        program = "${drv}/bin/${drv.name}";
      }) mcreatorPackages;

    in {
      packages.x86_64-linux = mcreatorPackages;
      apps.x86_64-linux = mcreaotrApps;
    };

}
