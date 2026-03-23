# CDP Boundary Values and Real Machine Testing

## Boundary Values

| Parameter | Default | Min | Max | Recommended |
|-----------|---------|-----|-----|------------|
| `waitMs` | 8000 | 0 | 120000 | 8000-30000 |
| `pollMs` | 250 | 50 | 10000 | 100-500 |
| `timeoutMs` | 60000 | 1000 | 300000 | 30000-60000 |
| `retryCount` | 3 | 1 | 10 | 3 |
| `chunkSize` | 800 | 100 | 5000 | 500-1000 |

## Real Machine Testing Checklist

### J1: Headless Mode

```bash
# Start headless Chromium
HQ_CHROME_HEADLESS=1 chromium-cdp

# Verify CDP port
curl http://127.0.0.1:9222/json/version
```

### J2: Headful Mode

```bash
# Start headful Chromium
chromium-cdp

# Verify CDP port
curl http://127.0.0.1:9222/json/version
```

### J3: Profile Reuse

```bash
# Set profile directory
export HQ_CHROME_PROFILE_DIR=~/.secret/hq/chromium-cdp-profile

# Start with profile
chromium-cdp

# After login, publish profile
chromium-cdp-service-profile-publish
```

### J4: Multiple Tabs

```bash
# Open multiple tabs
cdp-bridge new --url "https://chatgpt.com/c/thread1"
cdp-bridge new --url "https://chatgpt.com/c/thread2"

# List tabs
cdp-bridge list

# Send to specific tab by ID
qjs --std -m chromium-cdp.send-chatgpt.mjs --id <tab-id> --text "hello"
```

### J5: Long Connection

```bash
# Monitor WS connection stability
watch -n 5 'cdp-bridge list'

# Reconnect if needed
cdp-bridge close --id <stale-tab-id>
cdp-bridge new --url <url>
```

## Error Recovery Scenarios

### Browser Crash

```bash
# Detect
curl http://127.0.0.1:9222/json/version  # fails

# Recovery
pkill chromium
chromium-cdp
```

### WS URL Expired

```bash
# Detect
cdp-bridge list  # shows tab without webSocketDebuggerUrl

# Recovery
cdp-bridge close --id <tab-id>
cdp-bridge new --url <url>
```

### Rate Limiting

```bash
# Detect
# GPT returns rate limit message

# Recovery
# Wait 60 seconds and retry
# Or use different ChatGPT account
```
