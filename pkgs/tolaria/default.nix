{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  gtk3,
  glib,
  gdk-pixbuf,
  cairo,
  pango,
  dbus,
  openssl,
  webkitgtk_4_1,
  libsoup_3,
  fcitx5-gtk,
  nodejs,
  git,
  desktop-file-utils,
  xdg-utils,
  hicolor-icon-theme,
  gst_all_1,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "tolaria";
  version = "2026.9.24";

  # 采用上游 .deb（Depends: libwebkit2gtk-4.1-0, libgtk-3-0，即系统库），而非 AppImage。
  #
  # 为什么不用 AppImage：Tolaria 检测到 APPIMAGE/APPDIR 时会在启动阶段强制
  # （见上游 src-tauri/src/linux_appimage.rs）
  #   WEBKIT_DISABLE_DMABUF_RENDERER=1
  #   WEBKIT_DISABLE_COMPOSITING_MODE=1
  # WebKit 对后者是「变量存在即关闭」，于是退化为纯 CPU 光栅化，界面卡顿、输入延迟。
  # .deb 不带 AppImage 标记，走 Wayland 分支只关 DMABUF，硬件合成保留；
  # 同时用系统 fcitx5 输入法模块，打字不再经过 AppImage 内那份旧模块。
  src = fetchurl {
    url = "https://github.com/refactoringhq/tolaria/releases/download/v2026-09-24/Tolaria_${finalAttrs.version}_amd64.deb";
    hash = "sha256-4uI2/PFB7vHa3LZfnMde8RR+IvKaeP2tFFwrN3Kncds=";
  };

  nativeBuildInputs = [
    dpkg
    autoPatchelfHook
    wrapGAppsHook3
  ];

  buildInputs = [
    gtk3
    glib
    gdk-pixbuf
    cairo
    pango
    dbus
    openssl
    webkitgtk_4_1
    libsoup_3
    fcitx5-gtk # 提供 GTK3 的 im-fcitx5 模块，保证中文输入
    gst_all_1.gstreamer # WebKit 媒体预览；appsink 在 gst-plugins-base
    gst_all_1.gst-plugins-base
    gst_all_1.gst-plugins-good
    hicolor-icon-theme
  ];

  dontConfigure = true;
  dontBuild = true;

  # .deb 不是 stdenv 认得的归档，手动解包（ar + data.tar.gz 交给 dpkg-deb）。
  unpackPhase = ''
    runHook preUnpack
    dpkg-deb -x $src .
    runHook postUnpack
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -a usr/. $out/
    runHook postInstall
  '';

  # 应用运行期会 fork `node`（MCP / ws-bridge）、`git`（vault 操作），
  # 且启动 setup 会执行 `update-desktop-database`（注册 tolaria:// scheme），
  # 这些在纯 nix 包装环境里需显式进 PATH。
  # 注意：wrapGAppsHook3 不读取 makeWrapperArgs，必须追加到 gappsWrapperArgs。
  preFixup = ''
    gappsWrapperArgs+=(
      --prefix PATH : ${lib.makeBinPath [ nodejs git desktop-file-utils xdg-utils ]}
      # Tolaria 检测到 APPIMAGE/APPDIR 之外的 Wayland 会话时会把
      # WEBKIT_DISABLE_DMABUF_RENDERER 设成 1（弃用零拷贝合成路径）。
      # 这里预先设成非空的 "0"：Tolaria 的过滤逻辑会跳过覆盖，而 WebKit
      # 对该变量按值判断（"0" = 启用），从而保留 DMA-BUF 硬件合成。
      --set-default WEBKIT_DISABLE_DMABUF_RENDERER 0
    )
  '';

  meta = with lib; {
    description = "Tolaria - 桌面端 Markdown 知识库管理应用";
    homepage = "https://tolaria.md";
    downloadPage = "https://github.com/refactoringhq/tolaria/releases";
    license = licenses.agpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "tolaria";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
})
