{
  lib,
  buildNpmPackage,
  fetchurl,
  makeWrapper,
  nodejs_22,
  runCommandLocal,
}:
let
  version = "0.1.1-rc.2";

  # 上游 @deepseek-ai/dsh 的 npm tarball 不含 lockfile; 本目录的 package-lock.json
  # 由 `npm install --package-lock-only` 针对该版本生成 (566 包), 供 buildNpmPackage 复现依赖树。
  #
  # 版本说明: 不升级到 0.1.5-rc.2 — 该版本依赖 @deepseek-ai/dsh-experimental-code-runtime-python,
  # 而此包在 npm 上从未发布 (registry 404), 属于上游发布断裂, 无法安装。
  tarball = fetchurl {
    url = "https://registry.npmjs.org/@deepseek-ai/dsh/-/dsh-${version}.tgz";
    hash = "sha256-R+wF9FraWrh3ea4YqQRWtev/VCHcD/XBeWd9ZeHBYFc=";
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

    npmDepsHash = "sha256-8ajkHhlgQHMOO3xpRL+uqxfYgGq5JxT5eBDfZCaW7z4=";
    dontNpmBuild = true; # 上游 tarball 已含编译产物, 无 build script

    nativeBuildInputs = [makeWrapper];

    # npm 生成的 shebang 指向 /usr/bin/env node; 换成显式 node 22 包装,
    # 并补上 dsh 运行所需的 --expose-internals (与 dsh-fence 调用方式一致)。
    postInstall = ''
      rm -f $out/bin/dsh
      makeWrapper ${nodejs_22}/bin/node $out/bin/dsh \
        --add-flags "--expose-internals $out/lib/node_modules/@deepseek-ai/dsh/lib/bin.js"
    '';

    meta = {
      description = "DeepSeek Harness (dsh) - terminal AI coding agent harness";
      homepage = "https://github.com/deepseek-ai/deepseek-harness";
      license = lib.licenses.mit;
      mainProgram = "dsh";
      platforms = lib.platforms.linux;
    };
  }
