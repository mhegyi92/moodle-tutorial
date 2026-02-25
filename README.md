# Moodle Docker Setup

A self-contained Moodle development environment using Docker.

## Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│                        Docker Network                             │
│                       (moodle-network)                            │
├──────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐    │
│  │  moodle  │    │ mariadb  │    │  redis   │    │  ollama  │    │
│  │          │───▶│          │    │          │    │          │    │
│  │ Apache + │    │ Database │    │  Cache   │    │  Local   │    │
│  │  PHP 8.3 │───────────────────▶│ Sessions │    │   LLM    │    │
│  │          │─────────────────────────────────────▶│          │    │
│  └────┬─────┘    └──────────┘    └──────────┘    └──────────┘    │
│       │                                               ▲           │
│       │ Port 80                                Port 11434 (API)   │
│       ▼                                                           │
│  ┌──────────┐    ┌──────────┐                                    │
│  │   cron   │    │ mailpit  │                                    │
│  │          │    │          │                                    │
│  │ Scheduled│    │  Email   │◀─── Port 8025 (Web UI)             │
│  │  Tasks   │    │ Testing  │◀─── Port 1025 (SMTP)               │
│  └──────────┘    └──────────┘                                    │
│                                                                   │
└──────────────────────────────────────────────────────────────────┘

Volumes:
  moodle_data   → /var/www/moodledata (uploads, cache, sessions)
  moodle_html   → /var/www/html (Moodle code)
  mariadb_data  → /var/lib/mysql (database files)
  redis_data    → /data (cache persistence)
  ollama_data   → /root/.ollama (LLM models)
```

## Components

| Service | Image | Purpose |
|---------|-------|---------|
| **moodle** | Custom (PHP 8.3 + Apache) | Main Moodle application |
| **mariadb** | mariadb:10.11.11 | Database (LTS version) |
| **redis** | redis:7.4-alpine | Session and application cache |
| **ollama** | ollama/ollama:0.5.13 | Local LLM for AI features |
| **cron** | Same as moodle | Runs scheduled tasks every 60 seconds |
| **mailpit** | axllent/mailpit:v1.21 | Catches all outgoing emails for testing |

## Design Decisions

### Why Custom Dockerfile?

The Bitnami Moodle image is being discontinued (August 2025). Building our own image based on the official MoodleHQ PHP/Apache image gives us:

- Long-term maintainability
- Full control over installed packages
- Ability to add custom tools (Python for future integrations)
- Pinned versions for reproducibility

### Why MariaDB 10.11?

- Long Term Support (LTS) version
- Officially supported by Moodle
- UTF8MB4 support for full unicode (emojis, special characters)

### Why Redis?

Per official Moodle documentation: "The single biggest improvement to a Moodle site can be installing Redis."

Redis handles:
- Session storage (faster than database sessions)
- Application cache (reduces database load)
- Locking (prevents race conditions)

### Why Separate Cron Container?

Moodle requires cron to run every minute for:
- Sending forum notification emails
- Processing assignment submissions
- Running scheduled backups
- Cleaning up temporary files

A separate container keeps concerns isolated and makes logs easier to read.

### Why Mailpit?

Development environments shouldn't send real emails. Mailpit:
- Catches all outgoing SMTP mail
- Provides a web UI to view emails
- Helps test password resets, notifications, forum emails

### Why Ollama?

Ollama provides local LLM capabilities for Moodle's AI features:
- No external API costs (runs locally)
- Data privacy (nothing leaves your server)
- Works offline
- Supported natively by Moodle 4.5+ AI subsystem
- Can run models like Llama 3, Mistral, Phi, etc.

## Setup

### Prerequisites

- Docker and Docker Compose installed
- Ports 80, 1025, 8025, and 11434 available
- For GPU acceleration (optional): NVIDIA GPU with drivers and nvidia-container-toolkit

### Installation

1. Clone or download this repository

2. Build and start the containers:
   ```bash
   docker compose up -d --build
   ```

3. Wait for installation to complete (first run takes several minutes):
   ```bash
   docker compose logs -f moodle
   ```

   Look for: `Starting Apache...`

4. Access Moodle at http://localhost

### Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Moodle Admin | `admin` | `Admin123!` |
| MariaDB | `moodleuser` | `moodlepass` |
| MariaDB Root | `root` | `rootpassword` |

## Usage

### Starting and Stopping

```bash
# Start all services
docker compose up -d

# Stop all services (keeps data)
docker compose stop

# Stop and remove containers (keeps data in volumes)
docker compose down

# Stop and remove everything including data
docker compose down -v
```

### Viewing Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f moodle
docker compose logs -f mariadb
docker compose logs -f cron
```

### Accessing Containers

```bash
# Moodle container shell
docker exec -it moodle bash

# Run Moodle CLI commands
docker exec -it moodle php /var/www/html/admin/cli/cron.php
docker exec -it moodle php /var/www/html/admin/cli/purge_caches.php

# MariaDB shell
docker exec -it moodle-mariadb mariadb -u moodleuser -pmoodlepass moodle

# Redis CLI
docker exec -it moodle-redis redis-cli

# Ollama CLI
docker exec -it moodle-ollama ollama list
docker exec -it moodle-ollama ollama run llama3.2
```

### Email Testing

1. Open http://localhost:8025 (Mailpit Web UI)
2. Trigger an email in Moodle (e.g., password reset)
3. View the captured email in Mailpit

Note: SMTP must be configured in Moodle admin:
- Site Administration → Server → Email → Outgoing mail configuration
- SMTP Host: `mailpit`
- SMTP Port: `1025`

### Installing Plugins

```bash
# Enter the container
docker exec -it moodle bash

# Navigate to the appropriate directory
cd /var/www/html/mod  # for activity modules
cd /var/www/html/blocks  # for blocks
cd /var/www/html/theme  # for themes

# Download and extract plugin
# Then visit Site Administration → Notifications to complete installation
```

### Using Ollama (Local LLM)

#### Pull a Model

```bash
# Pull a model (first time only, models are persisted in volume)
docker exec -it moodle-ollama ollama pull llama3.2

# List available models
docker exec -it moodle-ollama ollama list

# Test a model
docker exec -it moodle-ollama ollama run llama3.2 "Hello, what can you do?"
```

#### Popular Models

| Model | Size | Best For |
|-------|------|----------|
| `llama3.2` | 2GB | General purpose, fast |
| `llama3.2:1b` | 1.3GB | Lightweight, very fast |
| `mistral` | 4GB | Good balance of speed/quality |
| `phi3` | 2.2GB | Microsoft's small model |
| `gemma2:2b` | 1.6GB | Google's lightweight model |

#### Configure in Moodle

1. Go to Site Administration → General → AI
2. Add a new AI Provider → Select "Ollama"
3. Configure:
   - Name: `Local Ollama`
   - API endpoint: `http://ollama:11434/api/generate`
4. Enable AI placements in Site Administration → General → AI placements

#### GPU Acceleration

For NVIDIA GPU support, uncomment the `deploy` section in `docker-compose.yml`:

```yaml
ollama:
  # ... other config ...
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: all
            capabilities: [gpu]
```

Requires nvidia-container-toolkit installed on the host.

## Troubleshooting

### Container won't start

Check if ports are already in use:
```bash
# Check port 80
sudo lsof -i :80

# Check port 8025
sudo lsof -i :8025
```

### 403 Forbidden Error

The Apache document root may not be set. Check logs:
```bash
docker compose logs moodle | grep -i error
```

If you see `APACHE_DOCUMENT_ROOT is not defined`, rebuild:
```bash
docker compose down
docker compose up -d --build
```

### Database Connection Failed

1. Check if MariaDB is healthy:
   ```bash
   docker compose ps
   ```

2. Check MariaDB logs:
   ```bash
   docker compose logs mariadb
   ```

3. Verify credentials match in `docker-compose.yml`

### Moodle Shows Installation Page Again

The config.php may be missing. Check if volumes are intact:
```bash
docker volume ls | grep moodle
```

If volumes were deleted, you'll need to reinstall:
```bash
docker compose down -v
docker compose up -d --build
```

### Cron Not Running

Check cron container status and logs:
```bash
docker compose ps cron
docker compose logs cron
```

The cron container waits 120 seconds after startup before running.

### Redis Not Working

1. Check Redis is running:
   ```bash
   docker exec -it moodle-redis redis-cli ping
   ```
   Should return: `PONG`

2. Check Redis config in Moodle:
   ```bash
   docker exec -it moodle grep -A5 "session_redis" /var/www/html/config.php
   ```

### Emails Not Appearing in Mailpit

1. Verify Mailpit is running: http://localhost:8025
2. Check SMTP settings in Moodle admin
3. Check Moodle logs for email errors:
   ```bash
   docker exec -it moodle tail -f /var/www/moodledata/moodle.log
   ```

### Slow Performance

1. Verify Redis is being used for caching
2. Check available memory:
   ```bash
   docker stats
   ```
3. Increase PHP memory limit in Dockerfile if needed

### Ollama Not Responding

1. Check if Ollama is running:
   ```bash
   docker compose ps ollama
   curl http://localhost:11434/api/tags
   ```

2. Check if a model is pulled:
   ```bash
   docker exec -it moodle-ollama ollama list
   ```

3. Check Ollama logs:
   ```bash
   docker compose logs ollama
   ```

4. If no models, pull one:
   ```bash
   docker exec -it moodle-ollama ollama pull llama3.2
   ```

### Reset Everything

To start completely fresh:
```bash
docker compose down -v
docker compose up -d --build
```

This removes all data including the database and uploaded files.

## File Structure

```
.
├── Dockerfile              # Custom Moodle image definition
├── docker-compose.yml      # Service definitions
├── docker-entrypoint.sh    # Startup script (installs Moodle, configures Redis)
└── README.md               # This file
```

## Customization

### Changing Moodle Version

Edit `docker-compose.yml`:
```yaml
args:
  MOODLE_VERSION: "MOODLE_405_STABLE"  # for Moodle 4.5
```

Available branches: https://github.com/moodle/moodle/branches

### Changing PHP Version

Edit `docker-compose.yml`:
```yaml
args:
  PHP_VERSION: "8.2"  # or 8.4
```

### Changing Credentials

Edit the environment variables in `docker-compose.yml`, then rebuild:
```bash
docker compose down -v  # Warning: deletes all data
docker compose up -d --build
```

## Resources

- [Moodle Documentation](https://docs.moodle.org/)
- [MoodleHQ Docker Images](https://github.com/moodlehq/moodle-php-apache)
- [Moodle CLI Scripts](https://docs.moodle.org/en/Administration_via_command_line)
- [Moodle AI Tools](https://docs.moodle.org/501/en/AI_tools)
- [Moodle Ollama Provider](https://docs.moodle.org/501/en/Ollama_API_provider)
- [Ollama Models Library](https://ollama.com/library)
