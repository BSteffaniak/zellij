{
  description = "Zellij - A terminal workspace with batteries included";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      flake-utils,
      rust-overlay,
    }:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        overlays = [ (import rust-overlay) ];
        pkgs = import nixpkgs {
          inherit system overlays;
        };

        # Rust toolchain matching rust-toolchain.toml
        rustToolchain = pkgs.rust-bin.stable."1.90.0".default.override {
          extensions = [
            "rustfmt"
            "clippy"
            "rust-src"
          ];
          targets = [
            "wasm32-wasip1"
            "x86_64-unknown-linux-musl"
          ];
        };

        # Build inputs needed for compilation
        nativeBuildInputs = with pkgs; [
          rustToolchain
          pkg-config
          protobuf # Provides protoc for prost
        ];

        buildInputs =
          with pkgs;
          [
            openssl
          ]
          ++ lib.optionals stdenv.isDarwin [
            darwin.apple_sdk.frameworks.Security
            darwin.apple_sdk.frameworks.SystemConfiguration
          ];

      in
      {
        # Development shell
        devShells.default = pkgs.mkShell {
          inherit nativeBuildInputs buildInputs;

          # Additional development tools
          packages = with pkgs; [
            cargo-watch
            rust-analyzer
            cargo-edit
            cargo-outdated
          ];

          # Environment variables
          PROTOC = "${pkgs.protobuf}/bin/protoc";
          PROTOC_INCLUDE = "${pkgs.protobuf}/include";

          shellHook = ''
            echo "🚀 Zellij development environment"
            echo "Rust toolchain: ${rustToolchain.version}"
            echo "protoc version: $(protoc --version)"
            echo ""
            echo "Available targets:"
            echo "  - wasm32-wasip1"
            echo "  - x86_64-unknown-linux-musl"
            echo ""
            echo "Run 'cargo build' to build the project"
          '';
        };

        # Package build
        packages.default = pkgs.rustPlatform.buildRustPackage {
          pname = "zellij";
          version = "0.44.0";

          src = ./.;

          cargoLock = {
            lockFile = ./Cargo.lock;
          };

          inherit nativeBuildInputs buildInputs;

          # Set protoc path
          PROTOC = "${pkgs.protobuf}/bin/protoc";
          PROTOC_INCLUDE = "${pkgs.protobuf}/include";

          meta = with pkgs.lib; {
            description = "A terminal workspace with batteries included";
            homepage = "https://zellij.dev";
            license = licenses.mit;
            maintainers = [ ];
          };
        };
      }
    );
}
