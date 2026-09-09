{
  description = "Reiky 的个人 Nix 私源包集合 (可复用 overlay) — Reiky-nixpkgs";

  # 独立可构建: 自带一个 nixpkgs 输入用于 `nix build .#<pkg>` 单测与 CI
  # 被主仓 NixMEOW 以 overlay 方式消费时, 走消费方的 nixpkgs (final.callPackage), 不依赖此输入
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [ "x86_64-linux" ];

      # 对每个 system 求值 (用于 packages / devShell / formatter)
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # 独立构建用的 pkgs 集 (放开 unfree 以便 firefox 系二进制)
      pkgsFor = system: import nixpkgs {
        inherit system;
        config.allowUnfree = true;
      };
    in
    {
      # 对外主接口: overlay
      # 用法(消费方 flake): nixpkgs.overlays = [ Reiky-nixpkgs.overlays.default ];
      overlays.default =
        final: prev:
        {
          zen-browser = final.callPackage ./pkgs/zen-browser { };
        };

      # 便于单包直接构建 / CI 冒烟测试: nix build .#zen-browser
      packages = forAllSystems (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          zen-browser = pkgs.callPackage ./pkgs/zen-browser { };
          default = pkgs.callPackage ./pkgs/zen-browser { };
        }
      );

      formatter = forAllSystems (system: (pkgsFor system).nixfmt-rfc-style);

      # 供 CI/CD 与文档引用的元信息
      hydraJobs = self.packages;
    };
}
