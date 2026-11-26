# Incident Notes: Project 24 — Manual Chaos Test (`httpd` Service Disruption)

## 1. Summary
- **Incident / Experiment ID:** P24-CHAOS-001
- **Status:** Resolved (Controlled Chaos Experiment)
- **Target Resource:** EC2 Instance `i-02ba6d6aca7211c58` (`18.212.28.93`, `us-east-1`, `t3.micro`, Security Group `yasir-p24-chaos-sg` allowing TCP 80 only; no SSH/RDP ports 22/3389)
- **Service Tested:** Apache HTTP Server (`httpd` / Apache 2.4.71 on Amazon Linux)
- **Total Stop-to-Verified-Recovery Window:** 15 seconds

## 2. steps
-  Baseline external HTTP check succeeded (`HTTP_STATUS=200`, body `<h1>Project 24 Chaos Target - Healthy (yasir-p24)</h1>`).
-  Chaos fault injected via AWS Systems Manager (`AWS-RunShellScript`) to stop `httpd` (`systemctl stop httpd`). Service state transitioned to `inactive` (SSM command status: `Success`). External `curl` probe failed with no HTTP response.
-  Remediation initiated via AWS Systems Manager (`systemctl start httpd`). Service state returned to `active` (SSM command status: `Success`).
-  External `curl -i` verification confirmed full recovery (`HTTP/1.1 200 OK`, `Server: Apache/2.4.71 (Amazon Linux)`).

## 3. Root Cause / Trigger
- Intentional manual chaos fault injection stopping the `httpd` systemd unit on `i-02ba6d6aca7211c58` to observe failure behavior and recovery timing.

## 4. Impact & Detection
- **Endpoint Impact:** HTTP requests on port `80` to `http://18.212.28.93/` did not return an `HTTP 200` response while `httpd` was stopped.
- **Detection & Control:** Verified via external `curl` health probes and remote `systemd` state checks over AWS SSM without exposing SSH (`22`) or RDP (`3389`).

## 5. Resolution & Recovery Verification
- Restarted `httpd` via `systemctl start httpd` over SSM and confirmed `systemctl is-active httpd` reported `active`.
- Verified external HTTP recovery at `2026-11-26T05:19:55Z` with `HTTP/1.1 200 OK` and expected response payload.
- Full raw CLI output recorded in `chaos-test-output.txt`.


