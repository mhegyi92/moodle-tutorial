# Moodle Docker Development Environment

A complete Moodle development environment using Docker. This setup is designed for plugin development with debugging, testing, and local AI capabilities.

## Table of Contents

- [Quick Start](#quick-start)
- [Architecture](#architecture)
- [Directory Structure](#directory-structure)
- [File Explanations](#file-explanations)
- [Configuration Options](#configuration-options)
- [Plugin Development](#plugin-development)
- [Testing](#testing)
- [Debugging](#debugging)
- [AI Integration (Ollama)](#ai-integration-ollama)
- [Common Tasks](#common-tasks)
- [Troubleshooting](#troubleshooting)
- [Resources](#resources)

---

## Quick Start

### 1. Prerequisites

Install these before starting:
- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (Windows/Mac) or Docker Engine (Linux)
- [Git](https://git-scm.com/downloads)
- A code editor ([VS Code](https://code.visualstudio.com/) recommended)

### 2. Clone and Setup

```bash
# Clone this repository
git clone https://github.com/mhegyi92/moodle-tutorial.git
cd moodle-tutorial

# Clone Moodle code (this takes a few minutes)
git clone --branch MOODLE_500_STABLE --depth 1 https://github.com/moodle/moodle.git moodle

# Start everything
docker compose up -d --build
```

### 3. Wait for Installation

First startup takes 3-5 minutes. Watch the progress:
```bash
docker compose logs -f moodle
```

When you see `Starting Apache...`, Moodle is ready.

### 4. Access Moodle

Open http://localhost in your browser.

**Login credentials:**
| Username | Password |
|----------|----------|
| `admin` | `Admin123!` |

---

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
│  ┌──────────┐    ┌──────────┐    ┌──────────┐                    │
│  │   cron   │    │ mailpit  │    │ selenium │                    │
│  │          │    │          │    │          │                    │
│  │ Scheduled│    │  Email   │    │  Behat   │                    │
│  │  Tasks   │    │ Testing  │    │  Tests   │                    │
│  └──────────┘    └──────────┘    └──────────┘                    │
│                       │               │                           │
│              Port 8025 (Web)   Port 7900 (VNC)                   │
└──────────────────────────────────────────────────────────────────┘
```

### What Each Service Does

| Service | Purpose | When You Need It |
|---------|---------|------------------|
| **moodle** | The main Moodle website | Always |
| **mariadb** | Stores all Moodle data (users, courses, etc.) | Always |
| **redis** | Makes Moodle faster by caching data | Always |
| **cron** | Runs background tasks (emails, cleanup) | Always |
| **mailpit** | Catches test emails so you can view them | When testing email features |
| **ollama** | Local AI for Moodle's AI features | When developing AI plugins |
| **selenium** | Runs automated browser tests | When running Behat tests |

---

## Directory Structure

```
moodle-tutorial/
│
├── moodle/                         # Moodle source code (you clone this)
│   ├── admin/                      # Admin scripts and pages
│   ├── blocks/                     # Block plugins
│   ├── local/                      # Local plugins (most common for custom development)
│   ├── mod/                        # Activity modules
│   ├── question/type/              # Question types
│   ├── theme/                      # Themes
│   └── ...                         # Many more directories
│
├── plugins/                        # Your plugin development folder
│   └── local_myplugin/             # Example: your local plugin
│
├── docker-compose.yml              # Main Docker configuration
├── docker-compose.override.yml     # Development settings (Xdebug, Selenium, etc.)
├── Dockerfile                      # How to build the Moodle container
├── docker-entrypoint.sh            # Startup script that installs Moodle
├── .gitignore                      # Files Git should ignore
├── .gitattributes                  # Git line ending settings (important for Windows)
└── README.md                       # This file
```

---

## File Explanations

### `docker-compose.yml` - Main Configuration

This file defines all the services (containers) that make up the environment.

**Key sections:**
```yaml
services:
  moodle:                    # The main Moodle container
    build: ...               # How to build it
    ports:
      - "80:80"              # Access on http://localhost
    environment:             # Settings passed to Moodle
      MOODLE_DB_HOST: mariadb
      MOODLE_ADMIN_PASSWORD: Admin123!
    volumes:                 # Folders shared with your computer
      - moodle_data:/var/www/moodledata
```

**To change Moodle version:**
```yaml
args:
  MOODLE_VERSION: "MOODLE_405_STABLE"  # Change this line
```

### `docker-compose.override.yml` - Development Settings

This file **automatically loads** when you run `docker compose up`. It adds:
- Xdebug for debugging
- Selenium for browser tests
- Local code mounting

**To disable development features:**
```bash
# Run without the override file
docker compose -f docker-compose.yml up -d
```

**To mount your plugin:**
```yaml
volumes:
  - ./moodle:/var/www/html
  - ./plugins/local_myplugin:/var/www/html/local/myplugin  # Add this line
```

### `Dockerfile` - Container Build Instructions

Defines how to build the Moodle container:
- Based on official MoodleHQ PHP/Apache image
- Installs additional tools (git, python, etc.)
- Sets PHP configuration

**You rarely need to edit this** unless adding system packages.

### `docker-entrypoint.sh` - Startup Script

Runs every time the container starts:
1. Clones Moodle if code not found
2. Waits for database to be ready
3. Installs Moodle (first run only)
4. Configures Redis caching
5. Sets up PHPUnit/Behat (if MOODLE_DEBUG=true)

---

## Configuration Options

### Environment Variables

Edit these in `docker-compose.yml` under `moodle: environment:`

| Variable | Default | What It Does |
|----------|---------|--------------|
| `MOODLE_URL` | `http://localhost` | The site URL |
| `MOODLE_ADMIN_USER` | `admin` | Admin username |
| `MOODLE_ADMIN_PASSWORD` | `Admin123!` | Admin password |
| `MOODLE_ADMIN_EMAIL` | `admin@example.com` | Admin email |
| `MOODLE_SITE_NAME` | `Moodle Development` | Site name shown in browser |
| `MOODLE_DB_TYPE` | `mariadb` | Database type |
| `MOODLE_DB_HOST` | `mariadb` | Database server |
| `MOODLE_DB_NAME` | `moodle` | Database name |
| `MOODLE_DB_USER` | `moodleuser` | Database username |
| `MOODLE_DB_PASSWORD` | `moodlepass` | Database password |
| `MOODLE_REDIS_HOST` | `redis` | Redis server for caching |
| `MOODLE_SMTP_HOST` | `mailpit` | Email server |

### Enabling/Disabling Features

#### Xdebug (Debugging)

**Enabled by default** in `docker-compose.override.yml`:
```yaml
environment:
  PHP_EXTENSION_xdebug: 1    # 1 = enabled, 0 = disabled
```

To disable (faster performance):
```yaml
  PHP_EXTENSION_xdebug: 0
```

#### Development Mode (Debug Output)

**Enabled by default** in `docker-compose.override.yml`:
```yaml
environment:
  MOODLE_DEBUG: "true"       # Shows detailed errors
```

To disable:
```yaml
  MOODLE_DEBUG: "false"
```

#### Selenium (Browser Tests)

**Enabled by default** in `docker-compose.override.yml`. To disable, comment out:
```yaml
# selenium:
#   image: selenium/standalone-chrome:131.0
#   ...
```

#### GPU Acceleration for Ollama

**Disabled by default**. To enable (requires NVIDIA GPU):

In `docker-compose.yml`, uncomment:
```yaml
ollama:
  # ...
  deploy:
    resources:
      reservations:
        devices:
          - driver: nvidia
            count: all
            capabilities: [gpu]
```

---

## Plugin Development

### Creating a New Plugin

1. Create your plugin folder:
   ```bash
   mkdir -p plugins/local_myplugin
   ```

2. Add required files (minimum):
   ```
   plugins/local_myplugin/
   ├── version.php          # Plugin version info (required)
   ├── lang/
   │   └── en/
   │       └── local_myplugin.php  # English strings
   └── db/
       └── access.php       # Permissions (if needed)
   ```

3. Mount it in `docker-compose.override.yml`:
   ```yaml
   volumes:
     - ./moodle:/var/www/html
     - ./plugins/local_myplugin:/var/www/html/local/myplugin
   ```

4. Restart containers:
   ```bash
   docker compose down && docker compose up -d
   ```

5. Install the plugin:
   - Go to http://localhost/admin
   - Moodle will detect the new plugin
   - Click "Upgrade Moodle database"

### Plugin Types and Locations

| Plugin Type | Folder | Example |
|-------------|--------|---------|
| Local plugins | `local/` | `local/myplugin` |
| Activity modules | `mod/` | `mod/myactivity` |
| Blocks | `blocks/` | `blocks/myblock` |
| Question types | `question/type/` | `question/type/myquestion` |
| Themes | `theme/` | `theme/mytheme` |
| Authentication | `auth/` | `auth/myauth` |
| Enrolment | `enrol/` | `enrol/myenrol` |
| Reports | `report/` | `report/myreport` |

### Editing Code

Your code in `./moodle` and `./plugins` is **live mounted**:
- Edit files with your IDE
- Changes appear immediately (no restart needed)
- For PHP changes, just refresh the browser
- For JavaScript, you may need to purge caches (see Common Tasks)

---

## Testing

### PHPUnit (Unit Tests)

Unit tests check individual functions work correctly.

```bash
# Initialize PHPUnit (first time only)
docker exec -it moodle php admin/tool/phpunit/cli/init.php

# Run all tests for your plugin
docker exec -it moodle vendor/bin/phpunit --testsuite local_myplugin_testsuite

# Run a specific test file
docker exec -it moodle vendor/bin/phpunit local/myplugin/tests/mytest_test.php

# Run with code coverage report
docker exec -it moodle php -d pcov.enabled=1 vendor/bin/phpunit --coverage-text local/myplugin/tests/
```

### Behat (Browser Tests)

Behat tests simulate real user interactions in a browser.

```bash
# Initialize Behat (first time only)
docker exec -it moodle php admin/tool/behat/cli/init.php

# Run all tests for your plugin
docker exec -it -u www-data moodle php admin/tool/behat/cli/run.php --tags=@local_myplugin

# Run a specific feature file
docker exec -it -u www-data moodle php admin/tool/behat/cli/run.php --feature=local/myplugin/tests/behat/myfeature.feature
```

**Watch tests in browser:** Open http://localhost:7900 (no password needed)

---

## Debugging

### Xdebug Setup

Xdebug lets you pause code execution and inspect variables.

#### VS Code Setup

1. Install the "PHP Debug" extension

2. Create `.vscode/launch.json`:
   ```json
   {
     "version": "0.2.0",
     "configurations": [
       {
         "name": "Listen for Xdebug",
         "type": "php",
         "request": "launch",
         "port": 9003,
         "pathMappings": {
           "/var/www/html": "${workspaceFolder}/moodle",
           "/var/www/html/local/myplugin": "${workspaceFolder}/plugins/local_myplugin"
         }
       }
     ]
   }
   ```

3. Click "Run and Debug" → "Listen for Xdebug"

4. Set breakpoints in your code (click left of line numbers)

5. Load a page in browser - VS Code will pause at breakpoints

#### PhpStorm Setup

1. Go to Settings → PHP → Debug
2. Set Xdebug port to `9003`
3. Go to Settings → PHP → Servers
4. Add server:
   - Name: `moodle`
   - Host: `localhost`
   - Port: `80`
   - Path mappings:
     - `/var/www/html` → `your-project/moodle`
5. Click "Start Listening for PHP Debug Connections" (phone icon)

### Viewing Logs

```bash
# All containers
docker compose logs -f

# Specific container
docker compose logs -f moodle
docker compose logs -f mariadb

# Moodle log file
docker exec -it moodle tail -f /var/www/moodledata/moodle.log
```

---

## AI Integration (Ollama)

Ollama runs AI models locally for Moodle's AI features.

### Pull a Model

```bash
# Small and fast (recommended to start)
docker exec -it moodle-ollama ollama pull llama3.2:1b

# Better quality, slower
docker exec -it moodle-ollama ollama pull llama3.2

# List installed models
docker exec -it moodle-ollama ollama list
```

### Configure in Moodle

1. Go to **Site Administration → General → AI**
2. Click **"Add a new AI provider instance"**
3. Select **"Ollama"**
4. Configure:
   - Name: `Local Ollama`
   - API endpoint: `http://ollama:11434/api/generate`
5. Click **"Create instance"**
6. Go to **Site Administration → General → AI placements**
7. Enable the placements you want

### Test It Works

```bash
curl http://localhost:11434/api/generate -d '{
  "model": "llama3.2:1b",
  "prompt": "Say hello",
  "stream": false
}'
```

---

## Common Tasks

### Start/Stop Environment

```bash
# Start
docker compose up -d

# Stop (keeps data)
docker compose stop

# Stop and remove containers (keeps data in volumes)
docker compose down

# Stop and DELETE ALL DATA
docker compose down -v
```

### Rebuild After Changes

```bash
# Rebuild containers
docker compose up -d --build
```

### Purge Moodle Caches

```bash
docker exec -it moodle php admin/cli/purge_caches.php
```

### Access Container Shell

```bash
# Moodle container
docker exec -it moodle bash

# Database
docker exec -it moodle-mariadb mariadb -u moodleuser -pmoodlepass moodle

# Redis
docker exec -it moodle-redis redis-cli
```

### View Emails

Open http://localhost:8025 to see all emails sent by Moodle.

### Run Moodle CLI Commands

```bash
# Upgrade database
docker exec -it moodle php admin/cli/upgrade.php

# Run cron manually
docker exec -it moodle php admin/cli/cron.php

# Create a user
docker exec -it moodle php admin/cli/create_user.php --username=test --password=Test123! --email=test@example.com --firstname=Test --lastname=User
```

### Check Container Status

```bash
docker compose ps
```

---

## Troubleshooting

### Container Won't Start

```bash
# Check what's wrong
docker compose logs moodle

# Check if ports are in use
# Linux/Mac:
lsof -i :80
# Windows (PowerShell):
netstat -ano | findstr :80
```

### 403 Forbidden Error

The Moodle code might be missing:
```bash
# Check if moodle folder exists and has files
ls moodle/

# If empty, clone it
git clone --branch MOODLE_500_STABLE --depth 1 https://github.com/moodle/moodle.git moodle
```

### Database Connection Failed

```bash
# Check if MariaDB is running
docker compose ps mariadb

# Check MariaDB logs
docker compose logs mariadb

# Verify it's healthy
docker exec -it moodle-mariadb mariadb -u moodleuser -pmoodlepass -e "SELECT 1"
```

### "exec format error" on Windows

Line endings issue. Fix:
```bash
# Delete and re-clone
rm -rf moodle-tutorial
git clone https://github.com/mhegyi92/moodle-tutorial.git
```

### Reset Everything

```bash
docker compose down -v
rm -rf moodle
git clone --branch MOODLE_500_STABLE --depth 1 https://github.com/moodle/moodle.git moodle
docker compose up -d --build
```

### Slow Performance

1. Disable Xdebug when not debugging:
   ```yaml
   # In docker-compose.override.yml
   PHP_EXTENSION_xdebug: 0
   ```

2. On Windows/Mac, Docker can be slow with many files. Consider using WSL2 (Windows) or increasing Docker resources.

---

## Resources

### Official Documentation
- [Moodle Documentation](https://docs.moodle.org/)
- [Moodle Developer Resources](https://moodledev.io/)
- [Plugin Development Guide](https://moodledev.io/docs/apis)

### Testing
- [PHPUnit in Moodle](https://moodledev.io/docs/guides/phpunit)
- [Behat in Moodle](https://moodledev.io/docs/guides/behat)

### AI Features
- [Moodle AI Tools](https://docs.moodle.org/501/en/AI_tools)
- [Ollama API Provider](https://docs.moodle.org/501/en/Ollama_API_provider)
- [Ollama Models Library](https://ollama.com/library)

### Docker
- [MoodleHQ Docker Images](https://github.com/moodlehq/moodle-php-apache)
- [Docker Compose Documentation](https://docs.docker.com/compose/)

---

## Default Credentials

| Service | Username | Password |
|---------|----------|----------|
| Moodle Admin | `admin` | `Admin123!` |
| MariaDB | `moodleuser` | `moodlepass` |
| MariaDB Root | `root` | `rootpassword` |
