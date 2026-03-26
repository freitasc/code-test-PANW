# Step 1: Builder
FROM python:3.10-slim AS builder

WORKDIR /build

# Install dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN pip install --no-cache-dir --prefix=/install -r requirements.txt

# Step 2: Final image
FROM python:3.10-slim

# Setup user and group
RUN groupadd -g 1000 app && \
    useradd -u 1000 -r -g app -d /app -s /usr/sbin/nologin app

WORKDIR /app

# Copy installed packages from builder
COPY --from=builder /install /usr/local

# Copy application code setting ownership to app
COPY --chown=root:root . .

# Create output directory with appropriate permissions
RUN mkdir -p /app/output && \
    chown 1000:1000 /app/output && \
    chmod 0700 /app/output && \
    chmod 0555 /app

# Switch to non-root user
USER 1000

CMD ["python", "main.py"]

# I did all this steps to ensure least privilege and hardening.
# 1. I created a non-root user and group to run the application, which reduces the risk of privilege escalation.
# 2. I set the ownership of the application files to root:root and made them read-only for the app, 
# which prevents unauthorized modifications.
# 3. I created an output directory with strict permissions (0700) to ensure that only the app can read/write to it
# 4. I set the permissions of the application directory to 0555, which allows read and execute permissions but prevents write access, further securing the application files.