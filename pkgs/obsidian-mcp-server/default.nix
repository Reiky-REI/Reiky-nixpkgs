{
  lib,
  buildNpmPackage,
  nodejs,
  runtimeShell,
}:
buildNpmPackage {
  pname = "obsidian-mcp-server";
  version = "0.1.0";

  # 源码从 ~/WorkSpace/tools/obsidian-mcp-server 收编: 一个 TypeScript 写的
  # Obsidian 仓库 MCP 服务器 (vault 读写 / 笔记整理)。
  # 原先靠家目录里的 flake 构建, 其 `result` 软链不是持久 GC root, 一次 GC 后
  # store 路径被回收, 导致 OpenCode / Claude Code / Codex 的 obsidian-vault
  # MCP 全部 spawn 失败。收进私源 + home.packages 后由用户 profile 托管, 稳定可用。
  src = ./.;

  npmDepsHash = "sha256-Dgj9LXsZqLtq7T8b0Kxu8dEdg2EVGTTqQaBk8L+r6M0=";

  # tsc 产物 (dist) + 运行时依赖 (node_modules), 再生成 bin 包装脚本。
  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin
    cp -r dist node_modules package.json $out/
    cat > $out/bin/obsidian-mcp-server <<EOF
    #!${runtimeShell}
    exec ${nodejs}/bin/node $out/dist/index.js "\$@"
    EOF
    chmod +x $out/bin/obsidian-mcp-server
    runHook postInstall
  '';

  meta = {
    description = "Obsidian vault MCP server (TypeScript) for note organization";
    homepage = "https://github.com/Reiky-REI/Reiky-nixpkgs";
    license = lib.licenses.mit;
    mainProgram = "obsidian-mcp-server";
    platforms = lib.platforms.linux;
  };
}
