{
  serviceName = "chromedevtoolprotocol-service";
  schemaVersion = 1;

  defaultEnv = {
    CHROME_SERVICE_ADDR = "127.0.0.1";
    CHROME_SERVICE_PORT = "9222";
    CHROME_SERVICE_SEED_PROFILE = "$HOME/.secret/hq/chromium-cdp-profile-140";
    CHROME_SERVICE_PUBLISHED_SNAPSHOT = "$HOME/.secret/hq/chromium-cdp-profile.snapshot";
    CHROME_SERVICE_SOURCE_PROFILE = "$HOME/.secret/hq/chromium-cdp-profile.snapshot";
    CHROME_SERVICE_APP_MATCH = "https://chatgpt.com";
    CHROME_SERVICE_START_URL = "about:blank";
    CHROME_SERVICE_BOOTSTRAP_URL = "https://chatgpt.com";
    CHROME_SERVICE_BOOTSTRAP_PORT = "9226";
    CHROME_SERVICE_BOOTSTRAP_VNC_PORT = "5902";
    CHROME_SERVICE_BOOTSTRAP_DISPLAY = ":98";
    CHROME_SERVICE_HEADLESS = "1";
    CHROME_SERVICE_ALLOW_RECOVER = "0";
    CHROME_SERVICE_PASSWORD_STORE = "basic";
    CHROME_SERVICE_DISABLE_AUTOMATION = "1";
    CHROME_SERVICE_SPOOF_USER_AGENT = "1";
    CHROME_SERVICE_HEALTH_SCOPE = "app";
    CHROME_SERVICE_APP_LOGIN_COOLDOWN_SEC = "300";
    CHROME_SERVICE_APP_CHALLENGE_COOLDOWN_SEC = "3600";
  };

  cleanupEntries = [
    "DevToolsActivePort"
    "SingletonCookie"
    "SingletonLock"
    "SingletonSocket"
  ];

  coreStatusValues = [
    "green"
    "degraded"
    "red"
    "config-error"
  ];

  chatgptStatusValues = [
    "logged-in"
    "login-required"
    "challenge-blocked"
    "probe-failed"
  ];

  healthExitCodes = {
    green = 0;
    degraded = 10;
    red = 20;
    configError = 30;
  };
}
