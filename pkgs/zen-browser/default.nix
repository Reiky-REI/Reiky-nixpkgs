{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  patchelfUnstable,
  makeWrapper,
  makeDesktopItem,
  copyDesktopItems,
  gtk3,
  glib,
  dbus,
  dbus-glib,
  alsa-lib,
  libGL,
  libxkbcommon,
  wayland,
  libx11,
  libxrender,
  libxtst,
  libxfixes,
  libxext,
  libxcb,
  pipewire,
  libva,
  pciutils,
  curl,
  adwaita-icon-theme,
}:
stdenv.mkDerivation (finalAttrs: {
  pname = "zen-browser";
  # 固定 1.21.16b (Gecko 154.0.1), 与用户手动下载的 tar.xz 一致
  # 升级流程见仓库 README 的 "如何更新版本" 一节
  version = "1.21.16b";

  # 上游官方通用 Linux 二进制 (非源码编译)
  # nixpkgs 至今未收录 zen-browser (26.05 / unstable 的 browsers/ 目录均无), 故本地打包
  src = fetchurl {
    url = "https://github.com/zen-browser/desktop/releases/download/${finalAttrs.version}/zen.linux-x86_64.tar.xz";
    hash = "sha256-Hkw8OR0QqCI501r62EZY+js4Vrj/cvk7v/f1c5KsuUI=";
  };

  # 压缩包顶层是 zen/ 目录, 切进去再安装
  sourceRoot = "zen";

  nativeBuildInputs = [
    autoPatchelfHook # 自动扫描 ELF 未定义符号, 把 Nix store 里的 .so 路径写进 RUNPATH
    patchelfUnstable # firefox 系二进制需要它配合 --no-clobber-old-sections
    makeWrapper # 生成 $out/bin/zen 启动包装
    copyDesktopItems # 安装 desktopItems 生成的 .desktop
  ];

  # 编译期/运行期都要的 GTK/X11 栈: firefox 家族二进制依赖系统这些库
  # (26.05 起 xorg.* 已弃用, 改用扁平包名 libx11/libxrender/...)
  buildInputs = [
    gtk3
    glib
    dbus
    dbus-glib
    alsa-lib
    libGL
    libxkbcommon
    wayland
    adwaita-icon-theme
    libx11
    libxrender
    libxtst
    libxfixes
    libxext
    libxcb
  ];

  # 仅运行期需要 (dlopen 或子进程使用)
  runtimeDependencies = [
    curl
    pciutils
    libva.out
    pipewire
  ];

  # Firefox/Zen 用 "relrhack" 从固定偏移手动处理重定位
  # patchelf 若覆盖旧 section 会导致启动即崩, 必须加这个 flag
  patchelfFlags = [ "--no-clobber-old-sections" ];

  installPhase = ''
    runHook preInstall

    # 整套文件原样放入 lib, 保持 zen / zen-bin / libxul.so / omni.ja 的相对布局
    # (zen 启动器靠 /proc/self/exe 定位自身目录, 再加载同级的 zen-bin 与 libxul.so)
    install -dm755 $out/lib/${finalAttrs.pname}-${finalAttrs.version}
    cp -r . $out/lib/${finalAttrs.pname}-${finalAttrs.version}

    # 启动包装: 注入 GTK schema / icon 路径后 exec 真实启动器
    # 用包装而非裸 symlink, 是为了不破坏启动器对同级资源的相对定位
    install -dm755 $out/bin
    makeWrapper $out/lib/${finalAttrs.pname}-${finalAttrs.version}/zen $out/bin/zen \
      --prefix XDG_DATA_DIRS : "${gtk3}/share:${glib}/share:${adwaita-icon-theme}/share" \
      --prefix LD_LIBRARY_PATH : "$out/lib/${finalAttrs.pname}-${finalAttrs.version}"

    # Nix store 只读, 上游自动更新必然失败并刷错误日志
    # 用 firefox 的 policies.json 机制显式禁用自动更新, 升级一律走 nix
    install -dm755 $out/lib/${finalAttrs.pname}-${finalAttrs.version}/distribution
    cat > $out/lib/${finalAttrs.pname}-${finalAttrs.version}/distribution/policies.json <<'JSON'
{
  "policies": {
    "DisableAppUpdate": true
  }
}
JSON

    runHook postInstall
  '';

  # 图标: 通用包不带 .desktop, 从包内 default128.png 铺到 hicolor 供启动器识别
  postFixup = ''
    install -Dm644 $out/lib/${finalAttrs.pname}-${finalAttrs.version}/browser/chrome/icons/default/default128.png \
      $out/share/icons/hicolor/128x128/apps/zen.png
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
      # Wayland app-id 与 WM_CLASS 都是 zen, 与命令行启动的 prgname 保持一致
      # (niri 窗口规则 app-id="zen" 依赖此值)
      startupWMClass = "zen";
    })
  ];

  meta = with lib; {
    description = "Zen Browser - 基于 Firefox 的隐私向浏览器 (官方通用二进制本地打包)";
    homepage = "https://zen-browser.app/";
    downloadPage = "https://github.com/zen-browser/desktop/releases";
    license = licenses.mpl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "zen";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
})
