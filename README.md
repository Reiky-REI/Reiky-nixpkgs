# Reiky-nixpkgs

Reiky 的个人 Nix 私源包集合，以 **flake overlay** 形式对外提供，供 [nixos-config (NixMEOW)](https://github.com/Reiky-REI/nixos-config) 及未来任意 NixOS/home-manager 配置复用。

> 定位：收录 nixpkgs 官方仓库**尚未打包**、或需要**固定特定版本/构建方式**的软件包。
> 与主仓解耦，便于单独维护、单独跑 CI/CD。

## 仓库结构

```
Reiky-nixpkgs/
├── flake.nix                 # 对外接口：overlays.default + packages.<system>
├── pkgs/
│   └── zen-browser/
│       └── default.nix       # Zen Browser（Firefox 分支）官方通用二进制打包
└── README.md
```

## 收录的包

| 包名 | 说明 | 为何本地打包 |
|------|------|-------------|
| `zen-browser` | [Zen Browser](https://zen-browser.app/)，基于 Firefox 的隐私向浏览器 | nixpkgs（26.05 与 unstable）`browsers/` 目录均未收录；上游以通用 Linux tarball 分发 |

## 作为 flake input 消费

在消费方（如 NixMEOW）的 `flake.nix`：

```nix
inputs = {
  # ...
  Reiky-nixpkgs.url = "github:Reiky-REI/Reiky-nixpkgs";
};
```

然后把 overlay 挂进 nixpkgs（`nixpkgs.overlays`）：

```nix
nixpkgs.overlays = [ Reiky-nixpkgs.overlays.default ];
```

之后 `pkgs.zen-browser` 即可在系统层或 home 层直接引用：

```nix
# home-manager 示例
home.packages = [ pkgs.zen-browser ];
```

> 说明：overlay 走消费方的 nixpkgs（`final.callPackage`），因此本仓库自带的 `nixpkgs` 输入**不影响**消费方版本，只用于独立构建与 CI。

## 独立构建 / 冒烟测试

```bash
nix build .#zen-browser          # 构建单包
nix run .#zen-browser            # 直接运行
nix flake check                  # 触发包求值
```

## zen-browser 包要点

- **来源**：`https://github.com/zen-browser/desktop/releases/download/<version>/zen.linux-x86_64.tar.xz`（官方通用二进制，非源码编译）。
- **入口**：`$out/bin/zen`（makeWrapper 包装，注入 `XDG_DATA_DIRS`/`LD_LIBRARY_PATH` 后 exec 真实启动器）。
- **Wayland app-id / WM_CLASS**：`zen`（命令行启动取 prgname）。主仓 niri 窗口规则 `app-id="zen"` 依赖此值。
- **禁用自动更新**：安装 `distribution/policies.json`（`DisableAppUpdate`）。Nix store 只读，上游自更新必然失败并刷错误日志，升级一律走 nix。
- **relrhack**：firefox 系二进制用固定偏移手动处理重定位，故用 `patchelfUnstable` + `--no-clobber-old-sections`，否则启动即崩。

### 如何更新版本

1. 去 [releases](https://github.com/zen-browser/desktop/releases) 找新版本号（如 `1.21.16b` → `x.y.z`）。
2. 改 `pkgs/zen-browser/default.nix` 的 `version`。
3. 先把 `hash` 临时改成 `lib.fakeHash`（或空串），跑：
   ```bash
   nix build .#zen-browser
   ```
   报错信息里的 `specified: sha256-...  got: sha256-...` 即新哈希，回填 `hash`。
   （或用 `nix-prefetch-url --unpack <url>` 拿 sha256 再 `nix hash to-sri`。）
4. `nix build .#zen-browser` 通过即完成。

## 未来 CI/CD 预留

`flake.nix` 已导出 `hydraJobs = packages`，可直接被 Hydra / GitHub Actions 复用。建议后续：

- **GitHub Actions + Cachix**：每次 push 构建 `packages.x86_64-linux.*` 并推缓存，主仓 `nixos-rebuild` 命中缓存秒装。
- **依赖更新**：`nix flake update`（更新自带 nixpkgs 输入）+ 用 `gh` API 检测 zen 新版本自动提 PR。
- 缓存公钥写入主仓 `flake.nix` 的 `nixConfig.trusted-public-keys`，substituters 指向 Cachix。

## License

仓库内自研的 Nix 打包代码采用 [MIT](LICENSE)。被打包软件自身的许可证见各包 `meta.license`（如 zen-browser 为 MPL-2.0）。
