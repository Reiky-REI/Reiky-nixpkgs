{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
let
  # 钉死上游 rev, 与 DeepSec clone 的 fff031f 一致; Cargo.lock 随源码提供,
  # 保证 crates.io 依赖树可复现 (无 git 依赖, 无需 outputHashes)。
  rev = "fff031fc01fb36b95348214c8ee359f6ede8aa8b";
  src = fetchFromGitHub {
    owner = "Unclecheng-li";
    repo = "DeepSec";
    inherit rev;
    hash = "sha256-z8TVWuLO03d3ZI4BK+kBBB8RfjJMR+0eagzU7DaYYVQ=";
  };
in
rustPlatform.buildRustPackage {
  pname = "deepsec-tui";
  version = "0.2.0";

  inherit src;

  # Rust 终端工作台 (ratatui/crossterm), 不随 Python 包分发;
  # deepsec/cli/tui.py 在 PATH 上查找 `deepsec-tui-native`。
  # 源码在仓库 tui/ 子目录, cargoRoot 定位 lockfile, buildAndTestSubdir 负责进目录构建。
  cargoRoot = "tui";
  buildAndTestSubdir = "tui";
  cargoLock.lockFile = "${src}/tui/Cargo.lock";

  meta = {
    description = "DeepSec TUI — terminal workbench for the DeepSec security platform";
    homepage = "https://github.com/Unclecheng-li/DeepSec";
    license = lib.licenses.mit;
    mainProgram = "deepsec-tui-native";
    platforms = lib.platforms.linux;
  };
}
