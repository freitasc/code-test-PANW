# code-test-PANW

A Python application that authenticates against a Prisma Cloud-compatible compliance API, fetches posture data, and exports the results to a CSV file. The application is packaged as a Docker image and deployed as a Kubernetes Job.

---

## Table of Contents

- [Overview](#overview)
- [Project Structure](#project-structure)
- [Prerequisites](#prerequisites)
- [Configuration](#configuration)
- [Running Locally](#running-locally)
- [Docker](#docker)
- [Kubernetes Deployment](#kubernetes-deployment)
- [Makefile Targets](#makefile-targets)
- [Security](#security)
- [Output](#output)

---

## Overview

The application performs the following steps:

1. **Login** – POSTs credentials to `<BASE_URL>/login` and retrieves a bearer token.
2. **Fetch Posture** – GETs compliance posture data from `<BASE_URL>/compliance/posture` using the token, filtered to the last 15 minutes.
3. **Export** – Pretty-prints the raw JSON response to stdout and writes the `complianceDetails` array to `./output/posture_data.csv`.

---

## Project Structure

```
.
├── config.py               # Loads BASE_URL from the environment
├── fetcher.py              # HTTPX client: login + fetch posture data
├── printer.py              # JSON pretty-print + CSV writer
├── main.py                 # Entry point
├── requirements.txt        # Python dependencies
├── Dockerfile              # Multi-stage, hardened Docker image
├── Makefile                # Automation helpers
├── .env.example            # Example environment file for local runs
└── k8/
    ├── jobs.yaml           # Kubernetes Namespace, PVC, Job, and output-reader Pod
    └── secrets.yaml.example  # Template for the BASE_URL Kubernetes Secret
```

---

## Prerequisites

| Tool       | Purpose                                  |
|------------|------------------------------------------|
| Python 3.10+ | Run the application locally             |
| Docker     | Build and run the container              |
| Minikube   | Local Kubernetes cluster                 |
| kubectl    | Kubernetes CLI                           |
| bandit     | Python static security analysis          |
| checkov    | Infrastructure-as-code security scanning |

Install the Python security tools with:

```bash
make install-tools
```

Verify all required tools are present with:

```bash
make check-tools
```

---

## Configuration

The only required configuration value is `BASE_URL` – the base URL of the compliance API (e.g. `https://api.prismacloud.io`).

### Local (`.env` file)

Copy the example file and fill in the value:

```bash
cp .env.example .env
# edit .env and set BASE_URL=https://<your-api-host>
```

`config.py` automatically loads `.env` via `python-dotenv`.

### Kubernetes (Secret)

Copy the secret template, base64-encode your URL, and apply it:

```bash
cp k8/secrets.yaml.example k8/secrets.yaml
# Edit k8/secrets.yaml and set BASE_URL to the base64-encoded value:
#   echo -n "https://<your-api-host>" | base64
kubectl apply -f k8/secrets.yaml
```

> **Never commit `k8/secrets.yaml` to source control.** It is listed in `.gitignore`.

---

## Running Locally

```bash
# 1. Create a virtual environment and install dependencies
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# 2. Configure the environment
cp .env.example .env
# Edit .env and set BASE_URL

# 3. Create the output directory
mkdir -p output

# 4. Run the application
python main.py
```

The application will print the JSON response to stdout and write `output/posture_data.csv`.

---

## Docker

### Build

```bash
# Build locally (using Minikube's Docker daemon so the image is available in-cluster)
eval $(minikube docker-env)
docker build -t code-test-image .
```

Or use the Makefile:

```bash
make build
```

### Run Standalone

```bash
docker run --rm \
  -e BASE_URL=https://<your-api-host> \
  -v $(pwd)/output:/app/output \
  code-test-image
```

---

## Kubernetes Deployment

The Kubernetes manifests in `k8/` define:

| Resource              | Kind                    | Purpose                                                     |
|-----------------------|-------------------------|-------------------------------------------------------------|
| `code-test`           | Namespace               | Isolates all resources                                      |
| `code-test-pvc`       | PersistentVolumeClaim   | Shared 1 GiB volume for the output CSV                      |
| `code-test-job`       | Job                     | Runs the application container once (`backoffLimit: 0`)     |
| `output-reader`       | Pod                     | Mounts the PVC so you can `kubectl cp` the CSV out          |

### Deploy

```bash
# Apply the secret first
kubectl apply -f k8/secrets.yaml

# Apply the Job and output-reader Pod
kubectl apply -f k8/jobs.yaml
```

Or use the Makefile:

```bash
make deploy
```

### Check Status

```bash
kubectl get jobs -n code-test
kubectl logs -l job-name=code-test-job -n code-test
```

### Retrieve Output

```bash
make fetch-output
# The CSV is copied to ./kube-output/posture_data.csv
```

### Full Workflow (build → deploy → fetch)

```bash
make run
```

### Clean Up

```bash
make clean
```

---

## Makefile Targets

| Target          | Description                                              |
|-----------------|----------------------------------------------------------|
| `help`          | List all available targets                               |
| `install-tools` | Install Bandit and Checkov via pip                       |
| `check-tools`   | Verify Minikube, kubectl, Docker, Bandit, Checkov exist  |
| `security-scan` | Run Bandit (Python) and Checkov (Dockerfile + k8) scans  |
| `build`         | Start Minikube and build the Docker image                |
| `deploy`        | Deploy the Job and Secret to Kubernetes                  |
| `fetch-output`  | Copy the output CSV from the cluster to `./kube-output/` |
| `run`           | `build` + `deploy` + `fetch-output`                      |
| `all`           | `check-tools` + `security-scan` + `run`                  |
| `clean`         | Delete Kubernetes resources and security scan reports    |

---

## Security

The following security measures are applied:

### Docker Image

- **Multi-stage build** – build dependencies are not included in the final image.
- **Non-root user** – the application runs as UID/GID `1000` (`app`).
- **Read-only application directory** – `/app` is set to `0555`; only `/app/output` is writable (`0700`).
- **Root-owned application files** – `COPY --chown=root:root` prevents the app user from modifying its own code.

### Kubernetes Job

- **`runAsNonRoot: true`** – enforced at the Pod security context level.
- **`allowPrivilegeEscalation: false`** – prevents the process from gaining additional privileges.
- **`capabilities: drop: ["ALL"]`** – all Linux capabilities are dropped.
- **`readOnlyRootFilesystem: true`** – the container filesystem is read-only (output is written to the mounted PVC).

### Static Analysis

```bash
make security-scan
```

Generates:

| Report                   | Tool     | Scope                  |
|--------------------------|----------|------------------------|
| `bandit_report.json`     | Bandit   | Python source code     |
| `checkov_docker_report/` | Checkov  | `Dockerfile`           |
| `checkov_k8_report/`     | Checkov  | `k8/` manifests        |

---

## Output

After a successful run the application produces:

- **stdout** – the full JSON response from the compliance posture API, pretty-printed with 2-space indentation.
- **`output/posture_data.csv`** – a CSV file containing the `complianceDetails` array with the following columns:

| Column                                   | Source field                        |
|------------------------------------------|-------------------------------------|
| `id`                                     | `id`                                |
| `name`                                   | `name`                              |
| `description`                            | `description`                       |
| `assigned_policies`                      | `assignedPolicies`                  |
| `failed_resources`                       | `failedResources`                   |
| `passed_resources`                       | `passedResources`                   |
| `total_resources`                        | `totalResources`                    |
| `critical_severity_failed_resources`     | `criticalSeverityFailedResources`   |
| `high_severity_failed_resources`         | `highSeverityFailedResources`       |
| `medium_severity_failed_resources`       | `mediumSeverityFailedResources`     |
| `low_severity_failed_resources`          | `lowSeverityFailedResources`        |
| `informational_severity_failed_resources`| `informationalSeverityFailedResources` |
| `is_default`                             | `default`                           |
