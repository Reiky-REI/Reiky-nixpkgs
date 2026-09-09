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
  gsettings-desktop-schemas,
  librsvg,
  ffmpeg_7,
  udev,
  libgbm,
  libnotify,
  libxscrnsaver,
  libpulseaudio,
  libcanberra-gtk3,
  libglvnd,
  vulkan-loader,
  pciutils,
  libkrb5,
  speechd-minimal,
  cups,
}:
let
  # 运行时 dlopen 的媒体/辅助库集, 通过 makeWrapper 注入 LD_LIBRARY_PATH 提供。
  #
  # 背景: Zen 1.21.16b (新版 Firefox 基座) 已移除 GStreamer 后端, 视频/音频解码
  # 改为运行时 dlopen 系统 FFmpeg (FFmpegLinkage 探测 libavcodec.so.53~63)。
  # 若这些库不在进程的 RPATH/LD_LIBRARY_PATH 中, dlopen 失败 -> canPlayType()
  # 对 H.264/AAC 返回空 -> 网课平台误报"请安装 Flash"。此前 Nix 版曾因缺 ffmpeg
  # 触发该问题, 经 steam-run 跑 Downloads 版却正常, 即因 FHS 环境自带这些库。
  #
  # 参考 nixpkgs firefox 的 wrapper.nix 的 libs 集。注意:
  #   - ffmpeg 是 split output, 真库在 .lib (libavcodec.so.61 / libavutil.so.59 / libswresample.so.5)
  #   - udev 在 nixpkgs 由 systemd-minimal-libs 提供
  #   - speechd-minimal 供 SpeechSynthesis API (缺失会报 "Speech Dispatcher required")
  mediaLibs = [
    ffmpeg_7.lib # H.264/AAC/MP3 等视频音频编解码 (libavcodec/libavutil/libswresample)
    udev # 设备管理, Firefox 通过它感知硬件(via systemd-minimal-libs)
    libgbm # GBM 图形缓冲分配, VA-API/硬解与合成器交互依赖
    libnotify # 桌面通知 (网页通知/下载完成提示)
    libxscrnsaver # X11 屏幕保护抑制 (全屏/播放时防熄屏)
    libpulseaudio # PulseAudio 音频输出后端 (无它声音走 pipewire 之外的回退路径需它)
    libcanberra-gtk3 # GTK 事件音效 (libcanberra), 通知/交互提示音需要
    libglvnd # GL Vendor 分发器, 链接核心 GL 入口 (mesa/nvidia 统一入口)
    vulkan-loader # Vulkan loader, WebGL/Canvas 走 Vulkan 后端时依赖
    pciutils # PCI 设备查询 (硬解/GPU 能力探测)
    libkrb5 # Kerberos 支持 (gssSupport, 企业认证/单点登录)
    speechd-minimal # SpeechSynthesis API 语音合成 (缺失报 "Speech Dispatcher required")
    cups # CUPS 打印支持 (打印/打印机探测时需 libcups)
  ];
in
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
      --prefix XDG_DATA_DIRS : "${gsettings-desktop-schemas}/share/gsettings-schemas/${gsettings-desktop-schemas.name}" \
      --prefix XDG_DATA_DIRS : "${gtk3}/share/gsettings-schemas/${gtk3.name}" \
      --prefix XDG_DATA_DIRS : "${glib}/share" \
      --set GDK_PIXBUF_MODULE_FILE "${librsvg}/lib/gdk-pixbuf-2.0/2.10.0/loaders.cache" \
      --unset GIO_EXTRA_MODULES \
      --set MOZ_LEGACY_PROFILES 1 \
      --set MOZ_ALLOW_DOWNGRADE 1 \
      --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath mediaLibs}"

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
