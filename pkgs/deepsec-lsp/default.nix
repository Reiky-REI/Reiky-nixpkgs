{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
let
  # 与 deepsec-tui 同源同 rev; 供编辑器 LSP 桥接使用 (VSCode/JetBrains 扩展)。
  rev = "fff031fc01fb36b95348214c8ee359f6ede8aa8b";
  src = fetchFromGitHub {
    owner = "Unclecheng-li";
    repo = "DeepSec";
    inherit rev;
    hash = "sha256-z8TVWuLO03d3ZI4BK+kBBB8RfjJMR+0eagzU7DaYYVQ=";
  };
in
rustPlatform.buildRustPackage {
  pname = "deepsec-lsp";
  version = "0.1.0";

  inherit src;

  # LSP 语言服务器, 源码在 rust-lsp/ 子目录; rusqlite 走 bundled(sqlite C 源码),
  # 首次构建耗时较长属预期。
  cargoRoot = "rust-lsp";
  buildAndTestSubdir = "rust-lsp";
  cargoLock.lockFile = "${src}/rust-lsp/Cargo.lock";

  meta = {
    description = "DeepSec LSP — native language server bridging DeepSec Shield scans into editor diagnostics";
    homepage = "https://github.com/Unclecheng-li/DeepSec";
    license = lib.licenses.mit;
    mainProgram = "deepsec-lsp";
    platforms = lib.platforms.linux;
  };
}
