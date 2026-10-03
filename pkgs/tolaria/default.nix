{
  lib,
  appimageTools,
  fetchurl,
  harfbuzz,
  fribidi,
  libgpg-error,
}:
let
  pname = "tolaria";
  version = "2026.9.24";

  # 上游 Linux 分发为 Tauri 打包的 AppImage（linuxdeploy-plugin-gtk 密封运行时）:
  # 内部已自带 webkit2gtk-4.1 / javascriptcoregtk-4.1 / libsoup-3.0 / gtk-3 等
  # 共 168 支 .so，无需从 nixpkgs 再补 webkit。
  # 版本号注意: tag 用 vYYYY-MM-DD，而产物文件名用点分 YYYY.M.D（如 v2026-09-24 -> 2026.9.24）。
  src = fetchurl {
    url = "https://github.com/refactoringhq/tolaria/releases/download/v2026-09-24/Tolaria_${version}_amd64.AppImage";
    hash = "sha256-q8HpHgctRjoqeNTVagHuxt1RUMlwu5F0fRVmYbydrqU=";
  };

  appimageContents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # AppImage 自带的 GTK 栈通过 $APPDIR/usr/lib 注入 LD_LIBRARY_PATH，优先于 FHS。
  # 这里只补 buildFHSEnv 默认集缺失、且被 pango/glib 在运行期 dlopen 的库，
  # 否则启动即报 libharfbuzz/libfribidi not found。
  extraPkgs = pkgs: with pkgs; [
    harfbuzz
    fribidi
    libgpg-error
  ];

  # AppImage 自带 .desktop 与 hicolor 图标，但 FHS 包装不会自动安装，
  # 显式装进输出以便生成桌面入口（StartupWMClass=tolaria，X11/XWayland 下生效）。
  extraInstallCommands = ''
    install -Dm644 ${appimageContents}/Tolaria.desktop \
      $out/share/applications/tolaria.desktop
    # 上游 .desktop 里 StartupWMClass=tolaria，但 Tauri/XWayland 实际 WM_CLASS 是
    # 大写的 "Tolaria"（niri 实测 app-id="Tolaria"），对齐以免任务栏无法关联图标。
    substituteInPlace $out/share/applications/tolaria.desktop \
      --replace-fail "StartupWMClass=tolaria" "StartupWMClass=Tolaria"
    for size in 32x32 128x128 256x256@2; do
      install -Dm644 ${appimageContents}/usr/share/icons/hicolor/$size/apps/tolaria.png \
        $out/share/icons/hicolor/$size/apps/tolaria.png
    done
  '';

  meta = with lib; {
    description = "Tolaria - 桌面端 Markdown 知识库管理应用（官方 AppImage 密封运行时）";
    homepage = "https://tolaria.md";
    downloadPage = "https://github.com/refactoringhq/tolaria/releases";
    license = licenses.agpl3Plus;
    platforms = [ "x86_64-linux" ];
    mainProgram = "tolaria";
    sourceProvenance = with sourceTypes; [ binaryNativeCode ];
  };
}
