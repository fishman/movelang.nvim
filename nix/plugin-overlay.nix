{
  self,
  name,
}: final: prev: let
  movelang-luaPackage-override = luaself: luaprev: {
    movelang = luaself.callPackage ({
      luaOlder,
      buildLuarocksPackage,
      lua,
    }:
      buildLuarocksPackage {
        pname = name;
        version = "scm-1";
        knownRockspec = "${self}/movelang-scm-1.rockspec";
        src = self;
        disabled = luaOlder "5.1";
      }) {};
  };

  lua5_1 = prev.lua5_1.override {
    packageOverrides = movelang-luaPackage-override;
  };
  luajit = prev.luajit.override {
    packageOverrides = movelang-luaPackage-override;
  };

  lua51Packages = final.lua5_1.pkgs;
  luajitPackages = final.luajit.pkgs;
in {
  inherit
    lua5_1
    lua51Packages
    luajit
    luajitPackages
    ;

  vimPlugins =
    prev.vimPlugins
    // {
      movelang = final.neovimUtils.buildNeovimPlugin {
        luaAttr = final.luajitPackages.movelang;
      };
    };

  movelang = final.vimPlugins.movelang;

  codelldb = final.vscode-extensions.vadimcn.vscode-lldb.adapter;
}
