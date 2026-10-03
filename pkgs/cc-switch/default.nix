{
  lib,
  stdenv,
  fetchurl,
}:
stdenv.mkDerivation {
  pname = "cc-switch";
  version = "5.10.5";

  # 上游以 GitHub Release 分发预编译原生二进制 (Rust);
  # nixpkgs 未收录, 故收进私源统一声明式管理, 取代原先手装的 ~/.local/bin/cc-switch。
  # 原生 ELF 由系统 programs.nix-ld 提供 glibc 兼容层, 实测可直接运行。
  src = fetchurl {
    url = "https://github.com/SaladDay/cc-switch-cli/releases/download/v5.10.5/cc-switch-cli-linux-x64.tar.gz";
    hash = "sha256-t4tRbASlne2wo6iISBSOQ2dkgJSPrWV3/1OWz4L1OWM=";
  };

  # 单文件二进制不改 ELF 不打条, 保持上游字节 (避免 nix-ld / 自更新签名校验被破坏)。
  dontPatchELF = true;
  dontStrip = true;

  # tar 内只有单个 cc-switch 文件、无顶层目录, 需显式 sourceRoot 跳过自动探测
  # (否则 unpackPhase 报 "unpacker appears to have produced no directories")。
  sourceRoot = ".";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 cc-switch $out/bin/cc-switch
    runHook postInstall
  '';

  meta = {
    description = "CC Switch CLI — 统一管理 Claude Code / Codex / Gemini / OpenCode 的 provider、MCP、代理与技能";
    homepage = "https://github.com/SaladDay/cc-switch-cli";
    license = lib.licenses.mit;
    mainProgram = "cc-switch";
    platforms = lib.platforms.linux;
  };
}
