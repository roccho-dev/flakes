rec {
  configPath = ../../opencode.json;
  defaultEnv = {
    OPENCODE_CONFIG = toString configPath;
    OPENCODE_DISABLE_LSP_DOWNLOAD = "true";
    OPENCODE_DISABLE_AUTOUPDATE = "true";
  };
}
