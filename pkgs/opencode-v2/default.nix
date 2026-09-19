{
  lib,
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation {
  pname = "opencode";
  version = "2.0.10";

  # 上游 v2 以 npm 平台包分发预编译原生二进制 (bun compile);
  # nixpkgs 目前只收录 v1 (1.18.x), 故本地打包。
  # 其他平台包名形如 @opencode/cli-{darwin,linux,windows}-{x64,arm64}。
  src = fetchurl {
    url = "https://registry.npmjs.org/@opencode/cli-linux-x64/-/cli-linux-x64-2.0.10.tgz";
    hash = "sha256-yjyE14yRAFlg758/fWDH37Sy21i5ewcA5OOUoDvY9C8=";
  };

  # bun compile 出来的单文件二进制把应用负载追加在 ELF 尾部;
  # autoPatchelf / strip 会破坏该负载, 导致退化成裸 bun (--version 打印 Bun 版本)。
  # 故一律不 patch 不打条: 本机 glibc 由系统 FHS shim 提供, 实测可直接运行。
  dontPatchELF = true;
  dontStrip = true;

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/opencode $out/bin/opencode
    runHook postInstall
  '';

  meta = {
    description = "OpenCode v2 — open source AI coding agent (CLI, native binary)";
    homepage = "https://opencode.ai";
    license = lib.licenses.mit;
    mainProgram = "opencode";
    platforms = lib.platforms.linux;
  };
}
