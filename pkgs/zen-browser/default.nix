{
  lib,
  stdenv,
  fetchurl,
  makeDesktopItem,
  copyDesktopItems,
  autoPatchelfHook,
  patchelfUnstable,
  makeWrapper,
  gtk3,
  adwaita-icon-theme,
  alsa-lib,
  dbus-glib,
  libxtst,
  libva,
  pipewire,
  glib,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "zen-browser";
  version = "1.21.16b";

  src = fetchurl {
    url = "https://github.com/zen-browser/desktop/releases/download/${finalAttrs.version}/zen.linux-x86_64.tar.xz";
    hash = "sha256-Hkw8OR0QqCI501r62EZY+js4Vrj/cvk7v/f1c5KsuUI=";
  };

  sourceRoot = "zen";

  nativeBuildInputs = [
    autoPatchelfHook
    patchelfUnstable
    makeWrapper
    copyDesktopItems
  ];

  buildInputs = [
    gtk3
    adwaita-icon-theme
    alsa-lib
    dbus-glib
    libxtst
  ];

  runtimeDependencies = [
    libva.out
  ];

  appendRunpaths = [
    "${pipewire}/lib"
  ];

  patchelfFlags = [ "--no-clobber-old-sections" ];

  dontWrapGApps = true;

  installPhase = ''
    runHook preInstall

    install -dm755 $out/lib/${finalAttrs.pname}-${finalAttrs.version}
    cp -r * $out/lib/${finalAttrs.pname}-${finalAttrs.version}

    install -dm755 $out/bin
    makeWrapper $out/lib/${finalAttrs.pname}-${finalAttrs.version}/zen $out/bin/zen \
      --prefix XDG_DATA_DIRS : "${glib}/share"

    install -dm755 $out/lib/${finalAttrs.pname}-${finalAttrs.version}/distribution
    cat > $out/lib/${finalAttrs.pname}-${finalAttrs.version}/distribution/policies.json <<'JSON'
{
  "policies": {
    "DisableAppUpdate": true
  }
}
JSON

    install -Dm644 $out/lib/${finalAttrs.pname}-${finalAttrs.version}/browser/chrome/icons/default/default128.png \
      $out/share/icons/hicolor/128x128/apps/zen.png

    runHook postInstall
  '';

  desktopItems = [
    (makeDesktopItem {
      name = "zen";
      desktopName = "Zen Browser";
      genericName = "Web Browser";
      comment = "Zen Browser - 基于 Firefox 的隐私向浏览器";
      exec = "zen %u";
      icon = "zen";
      categories = [
        "Network"
        "WebBrowser"
      ];
      mimeTypes = [
        "x-scheme-handler/http"
        "x-scheme-handler/https"
        "text/html"
      ];
      startupWMClass = "zen";
    })
  ];

  meta = with lib; {
    description = "Zen Browser - 基于 Firefox 的隐私向浏览器 (官方二进制, autoPatchelf + makeWrapper)";
    homepage = "https://zen-browser.app/";
    downloadPage = "https://github.com/zen-browser/desktop/releases";
    license = licenses.mpl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "zen";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
})
