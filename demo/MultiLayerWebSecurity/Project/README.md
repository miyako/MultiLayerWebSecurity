# Sentinel Demo Application

A 4D v21.0 LTS web application that filters inbound HTTP requests through a layered defense pipeline. This file covers how to use the dashboard. It does not cover the codebase.

## Login

Open one of the following addresses in a web browser.


http://127.0.0.1:8044
http://127.0.0.1:8044/sentinel.html


The login page accepts three credential types.

Dynamic Passphrase Generation (DPG). Click the Generate button on the login page. A one-shot passphrase is shown and remains valid for five minutes for the IP that generated it.

Active DPG. A passphrase issued earlier and still within its validity window.

Static passphrase. The long-lived passphrase stored in Data/dosguard_config.json.

After five failed attempts within fifteen minutes, the source IP is locked out for thirty minutes. The lockout clears on 4D server restart.

After login the browser is redirected to /dashboard.html.

## Dashboard Layout

The dashboard groups information into seven blocks.

Header. Live clock, threat badge, theme toggle, logout.

Traffic Telemetry. Eight metric cards (total, allowed, blocked, rate limited, WAF, honeypot, panic, requests per minute).

Defense Master. Single switch that bypasses every defense layer when OFF.

Defense Layers. Four toggles (IP Interceptor, Rate Limit, Handler Defense, WAF).

Live Intelligence. CPU and traffic charts. IP blocklist and allowlist editors.

Operations. Workers, Alerts, Honeypot Hits panels.

Controls. Emergency Panic, Attack Simulation, Security Equalizer entry point, Keyboard Shortcuts.

Feed. Last 120 log lines with auto-scroll and CSV export.

## Defense Master and Defense Layers

The Master Switch is the global gate. When OFF, every defense layer is bypassed and every request is accepted. The dashboard panic indicator may still update while Master is OFF but no traffic is blocked.

The four Defense Layers can be toggled independently while Master is ON.

IP Interceptor. Enforces the blocklist and the strike counters.

Rate Limit. Applies the per-IP token bucket and the global rate cap.

Handler Defense. Applies header size limits and outer-perimeter filters.

WAF. Runs URL normalization and recon pattern detection.

## Panic Mode

Panic Mode rejects every request from a non-allowlisted source with HTTP 503.

Click Trigger in the Emergency Panic panel to start it. The default duration is sixty seconds and is editable in the input field. Click Lift to end Panic Mode early.

Allowlisted addresses bypass Panic Mode and keep access to the dashboard.

## Security Equalizer

Click Configure in the Security Equalizer panel. The browser opens /sentinel-config.html in a new tab. Editable settings include rate limit values, panic thresholds, CPU triggers, honeypot ban duration, alert thresholds, WAF behavior, and request validation limits.

Changes apply immediately after Save Configuration. Reset to Defaults restores factory values and preserves the authentication passphrase and the HTTP port.

## Attack Simulation

The Attack Simulation panel runs internal load scripts against the local web server.

CPU Armageddon. Floods /heavy to push CPU above the panic threshold.

Bandwidth Overcharge. Multi-vector traffic to exercise rate limits.

Header Overflow. Oversized, malformed, and CRLF-injected headers.

Ghost Flood. Fifty-IP distributed simulation.

Select a vector and click Launch. The dashboard surfaces the resulting metrics, blocks, and alerts.

## IP Blocklist and Allowlist

Both lists live in Data/ip_lists.json and are editable from the dashboard.

Add an entry through the input field above the list, or click an entry to remove it. The Clear All button empties both lists. Re-add 127.0.0.1 and any required LAN address after a Clear All operation.

## Alerts and Honeypot

The Alerts panel shows the most recent alerts with severity (INFO, WARNING, CRITICAL). Click an alert row to acknowledge it. Ack All acknowledges every alert. Clear removes every alert from memory.

The Honeypot Hits panel lists IPs that hit a decoy path. Each hit raises a CRITICAL alert and bans the source for twenty-four hours.

## Workers

The Workers panel lists the six background processes and their last heartbeat time. A worker shown as STALLED indicates a stuck duty cycle and triggers a WARNING alert.

## Keyboard Shortcuts

Cmd+K or Ctrl+K. Open or close Spotlight search.

/. Open Spotlight.

Up and Down arrows. Move through Spotlight results.

Enter. Select the highlighted Spotlight result.

Esc. Close Spotlight or any open overlay.

Shift+J. Collapse every panel.

Shift+K. Isolate the Live Intelligence Feed.

Shift+L. Expand every panel.

## Remote Test Scripts

The following short scripts run from a separate machine via macos terminal or powershell on the same network. Replace 192.168.XXX.YY with the IP of the host computer.

Send a clean request to the health endpoint.


curl -i http://192.168.XXX.YY:8044/health


Trigger the honeypot with a probe to a decoy path. Expect HTTP 403 and a CRITICAL alert on the dashboard.


curl -i http://192.168.XXX.YY:8044/.env
curl -i http://192.168.XXX.YY:8044/admin.php
curl -i http://192.168.XXX.YY:8044/wp-login.php


Trigger the WAF with a path traversal pattern.


curl -i "http://192.168.XXX.YY:8044/api/public/file?p=../../etc/passwd"


Trigger the WAF with a script tag in the URL.


curl -i "http://192.168.XXX.YY:8044/api/public/x?q=%3Cscript%3E"


Trigger a rate limit. The default per-IP cap is one hundred requests in sixty seconds.


for i in $(seq 1 200); do
  curl -s -o /dev/null -w "%{http_code} " http://192.168.XXX.YY:8044/health
done
echo


Trigger a burst block. The default burst threshold is twenty requests in five seconds.

`
for i in $(seq 1 25); do
  curl -s -o /dev/null http://192.168.XXX.YY:8044/health &
done
wait


Send a request without a User-Agent header. Sonar adds thirty points to the score.


curl -i -H "User-Agent:" http://192.168.XXX.YY:8044/api/public/x


For longer or more elaborate load tests, the user must provide their own scripts. The examples above cover only the basic verification paths.

## Notes

The dashboard polls the server on independent timers (1 Hz, 5 s, 10 s). Toggling a defense layer takes effect on the next inbound request. Configuration changes apply without a 4D server restart. Restarting 4D clears in-memory state (lockouts, recent alerts, request log ring buffer) but persisted state (blocklist, allowlist, daily logs, Sonar archives) survives.

The dashboard is intended for a single administrator session on the host machine. Concurrent administrator sessions are not designed for and are not supported.
