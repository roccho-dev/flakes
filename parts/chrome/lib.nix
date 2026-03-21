{
  serviceName = "chromedevtoolprotocol-service";
  schemaVersion = 1;

  defaultEnv = {
    CHROME_SERVICE_ADDR = "127.0.0.1";
    CHROME_SERVICE_PORT = "9222";
    CHROME_SERVICE_SOURCE_PROFILE = "$HOME/.secret/hq/chromium-cdp-profile.snapshot";
    CHROME_SERVICE_APP_MATCH = "https://chatgpt.com";
    CHROME_SERVICE_START_URL = "about:blank";
    CHROME_SERVICE_HEADLESS = "1";
    CHROME_SERVICE_ALLOW_RECOVER = "0";
    CHROME_SERVICE_PASSWORD_STORE = "";
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
