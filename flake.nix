{
  description = "tailcat: netcat over Tailscale's data plane, without its control plane";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        # go.mod requires Go 1.27, which is newer than the default
        # pkgs.go/buildGoModule as of 2026-08.
        buildGoModule = pkgs.buildGoModule.override { go = pkgs.go_1_27; };
      in
      {
        packages.default = buildGoModule {
          pname = "tailcat";
          version = self.shortRev or "dev";
          src = self;
          subPackages = [ "cmd/tailcat" ];
          vendorHash = "sha256-bCdCsYcoXQSSIe3aS73o7do+rbuNniPNw8yNwoEnH6A=";
          meta = {
            description = "netcat over Tailscale's data plane, without its control plane";
            homepage = "https://github.com/tailscale/tailcat";
            license = pkgs.lib.licenses.bsd3;
            mainProgram = "tailcat";
          };
        };

        devShells.default = pkgs.mkShell {
          packages = [ pkgs.go_1_27 ];
        };
      });
}
