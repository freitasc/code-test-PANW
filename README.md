# code-test-PANW

Security-focused Python workload that:

1. Authenticates to an external API
2. Fetches compliance posture data
3. Prints JSON to stdout
4. Exports `complianceDetails` to CSV
5. Runs as a Kubernetes `Job` with hardened container settings

---

## Project structure

- `main.py` — App entrypoint, orchestrates fetch + print/export
- `fetcher.py` — Login + data retrieval using `httpx`
- `printer.py` — Prints JSON and writes `./output/posture_data.csv`
- `config.py` — Loads `BASE_URL` from environment (`dotenv`)
- `Dockerfile` — Multi-stage build, non-root runtime, read-only filesystem
- `k8/jobs.yaml` — Namespace, PVC, job, and output-reader pod
- `k8/secrets.yaml` — Kubernetes secret with `BASE_URL`
- `requirements.txt` — Python dependencies
- `Makefile` — Helper targets (`build`, `deploy`, `fetch-output`, etc.)

---

## How it works

### Request flow

The app expects `BASE_URL` to include the API stage, for example:

- `https://wgyl9brnpk.execute-api.us-east-1.amazonaws.com/prod`

`fetcher.py` then calls:

1. `POST {BASE_URL}/login` with `username`/`password`
2. `GET {BASE_URL}/compliance/posture?timeType=relative&timeAmount=15&timeUnit=minute` with `token` header

### Output flow

`printer.py` writes CSV rows from `data["complianceDetails"]` to `/app/output/posture_data.csv` (inside container). When `make fetch-output` runs, the file is copied to `./kube-output/posture_data.csv`.

---

## Prerequisites

Install and ensure available in `PATH`:

- `python3`
- `docker`
- `kubectl`
- `minikube`
- (optional for security checks) `bandit`, `checkov`

Validate tooling with:

```zsh
make check-tools
```

---

## Configuration

### Kubernetes secret

`k8/secrets.yaml` should contain:

- Secret name: `code-test-secret`
- Key: `BASE_URL`
- Value: full API base URL including `/prod`

Current format using `stringData` is correct:

```yaml
apiVersion: v1
kind: Secret
metadata:
  name: code-test-secret
  namespace: code-test
type: Opaque
stringData:
  BASE_URL: "<API_BASE_URL_WITH_STAGE>"
```

---

## Run locally (without Kubernetes)

1. Create a `.env` file:

```dotenv
BASE_URL=<API_BASE_URL_WITH_STAGE>
```

2. Install dependencies and run:

```zsh
python3 -m pip install -r requirements.txt
python3 main.py
```

Expected outputs:

- Pretty JSON printed to stdout
- CSV written to `./output/posture_data.csv`

---

## Run with Kubernetes (Minikube)

### 1) Build image in Minikube Docker daemon

```zsh
make build
```

### 2) Deploy resources

```zsh
make deploy
```

### 3) Fetch generated CSV from cluster

```zsh
make fetch-output
```

The CSV will be copied to `./kube-output/posture_data.csv`.

---

## Makefile targets

- `make help` — List all targets
- `make install-tools` — Install Bandit and Checkov
- `make check-tools` — Verify required binaries
- `make security-scan` — Run Bandit + Checkov
- `make build` — Start Minikube and build Docker image
- `make deploy` — Apply job + secret manifests
- `make fetch-output` — Copy CSV from mounted volume
- `make run` — `build + deploy + fetch-output`
- `make clean` — Cleanup jobs/pods and reports

---

## Security hardening

From `Dockerfile` and `k8/jobs.yaml`:

- Non-root container user (`UID 1000`)
- Dropped Linux capabilities (`drop: ["ALL"]`)
- `allowPrivilegeEscalation: false`
- `readOnlyRootFilesystem: true`
- Dedicated writable mount only at `/app/output`
- `runAsNonRoot: true`
- `fsGroup: 1000`

These controls enforce least privilege and reduce attack surface.

---

## Troubleshooting

### Image pull failures

If the job pod is stuck in `ErrImagePull` or `ImagePullBackOff`:

- Ensure `kynanwontmiss/code-test:latest` exists and is accessible
- If using local-only image, run `make build` (builds inside Minikube Docker)
- Inspect events:

```zsh
kubectl describe pod -n code-test <pod-name>
kubectl get events -n code-test --sort-by=.lastTimestamp | tail -n 30
```

### DNS / network failures

`httpx.ConnectError: Temporary failure in name resolution` means cluster DNS/egress is down. Verify from a debug pod:

```zsh
kubectl run dns-test -n code-test --image=busybox:1.36 --rm -it --restart=Never -- nslookup wgyl9brnpk.execute-api.us-east-1.amazonaws.com
```

Fix CoreDNS or network policies before rerunning the job.

### No logs available

`kubectl logs` only shows output after the container starts. If pod status shows "waiting" (e.g., image pull), inspect events first.

---

## CSV schema

Generated `posture_data.csv` columns:

1. `id`
2. `name`
3. `description`
4. `assigned_policies`
5. `failed_resources`
6. `passed_resources`
7. `total_resources`
8. `critical_severity_failed_resources`
9. `high_severity_failed_resources`
10. `medium_severity_failed_resources`
11. `low_severity_failed_resources`
12. `informational_severity_failed_resources`
13. `is_default`

Each row corresponds to an entry in `complianceDetails` from the API response.

---

## Notes for reviewers

- Credentials are hardcoded in `fetcher.py` for the test (`testuser` / `testpassword`). For production, move them to secrets.
- `BASE_URL` secret must include the `/prod` stage to match API endpoints.
- The repo includes security scans (`make security-scan`) that always succeed by design (`|| true`) to avoid pipeline blockage while still generating reports.
