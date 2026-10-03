{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  runCommandLocal,
  stdenv,
  autoPatchelfHook,
}:
let
  version = "0.2.0-rc.2";

  # ── 为什么用官方 Node 二进制而不是 nixpkgs 的 nodejs_22 ──────────────────────
  # dsh 0.2.x 启动时必须通过原生 addon `node-addon-require-builtin` 反查 Node
  # 内部模块 (internal/modules/*)。该 addon 靠扫描 V8/Isolate 的机器码布局来定位
  # field getter, 而 nixpkgs 自编译的 Node 与官方构建的代码布局不同, 探测直接失败:
  #   Unsupported/no-getter (x64 sysv getter is not a recognized this->field accessor)
  # → dsh 以 "host preparation failed" 拒绝启动 (Node 22 / 24 均复现)。
  # 该 addon 只有 napi 预编译二进制 (prebuilds.json), 无纯 JS 回退路径。
  # 上游已知问题: deepseek-ai/deepseek-harness discussion #690「NixOS 上
  # node-addon-require-builtin 探测在 Nix 编译的 Node 上失败」。
  # 实测: 换用 nodejs.org 官方 linux-x64 构建后 dsh 0.2.0-rc.2 正常 boot。
  #
  # 取源用 npmmirror 的官方二进制镜像 (nodejs.org 直连不稳), 内容与
  # https://nodejs.org/dist/v${nodeVersion}/node-v${nodeVersion}-linux-x64.tar.xz 一致。
  nodeVersion = "22.23.2";
  nodeTarball = fetchurl {
    url = "https://registry.npmmirror.com/-/binary/node/v${nodeVersion}/node-v${nodeVersion}-linux-x64.tar.xz";
    hash = "sha256-1grP4AopMiVLsK0g4BsNdDl6CHVZXecZZUshT0sD8wc=";
  };

  node = stdenv.mkDerivation {
    pname = "nodejs-official";
    version = nodeVersion;
    src = nodeTarball;
    sourceRoot = "node-v${nodeVersion}-linux-x64";

    nativeBuildInputs = [autoPatchelfHook];
    buildInputs = [stdenv.cc.cc.lib]; # libstdc++ / libgcc_s

    dontConfigure = true;
    dontBuild = true;
    # 关键: 不做 strip。addon 靠机器码布局做探测, 保持官方二进制字节原样最稳。
    dontStrip = true;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      # 只取 node 本体 (约 125MB 的静态自洽二进制)。dsh 不需要 npm/npx/corepack,
      # 少装也可避免对整棵发行版跑 patchelf (慢且无必要)。
      cp -a bin/node $out/bin/node
      runHook postInstall
    '';

    meta = {
      description = "Node.js official linux-x64 binary (upstream build, for dsh native addon compatibility)";
      homepage = "https://nodejs.org/";
      license = lib.licenses.mit;
      platforms = ["x86_64-linux"];
      mainProgram = "node";
    };
  };

  # 上游 @deepseek-ai/dsh 的 npm tarball 不含 lockfile; 本目录的 package-lock.json
  # 由 `npm install --package-lock-only` 针对该版本生成 (646 包), 供 buildNpmPackage 复现依赖树。
  #
  # 版本说明: 从 0.1.1-rc.2 直接跳到 0.2.0-rc.2 (npm latest)。
  #   - 0.1.5-rc.2 因依赖 @deepseek-ai/dsh-experimental-code-runtime-python (npm 从未发布) 无法安装;
  #     0.2.0-rc.2 依赖树已不含该包, 断裂解除。
  #   - 0.2.x 才提供 @deepseek-ai/dsh-llm 的 ToolCallId 导出, dsh-tui 0.12.x 需要它。
  #   - 升级 0.2.x 同时要求 profile 插件跟上: @yejiming/dsh-data-agent >= 0.2.0-rc.1
  #     (0.1.x 的 data-agent 在 0.2 宿主上 peer 不满足)。
  tarball = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
    hash = "sha256-vSeEfERc1opWWsH5HAa7vMdjnvkwcfZ4u1nF66/ziFk=";
  };

  src = runCommandLocal "dsh-${version}-src" {} ''
    mkdir -p $out
    tar -xzf ${tarball} -C $out --strip-components=1
    cp ${./package-lock.json} $out/package-lock.json
  '';
in
  buildNpmPackage {
    pname = "dsh";
    inherit version src;

    npmDepsHash = "sha256-sx/nXrhS9U3NhEOEmcEpzDm06lSh9MQBDb6vqD0AG6o=";
    dontNpmBuild = true; # 上游 tarball 已含编译产物, 无 build script

    nativeBuildInputs = [makeWrapper];

    # npm 生成的 shebang 指向 /usr/bin/env node; 换成官方 node 包装,
    # 并补上 dsh 运行所需的 --expose-internals (与 dsh-fence 调用方式一致)。
    postInstall = ''
      rm -f $out/bin/dsh
      makeWrapper ${node}/bin/node $out/bin/dsh \
        --add-flags "--expose-internals $out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"
    '';

    meta = {
      description = "DeepSeek Harness (dsh) - terminal AI coding agent harness";
      homepage = "https://github.com/deepseek-ai/deepseek-harness";
      license = lib.licenses.mit;
      mainProgram = "dsh";
      platforms = ["x86_64-linux"];
    };
  }
