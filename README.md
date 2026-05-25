# Literate Broccoli
## Introduction
Literate Broccoli is a Dockerized ERPNext project that utilizes a MariaDB database. It provides a comprehensive enterprise resource planning system with a wide range of features.
## Key Features
* Dockerized for easy deployment and management
* MariaDB database for reliable data storage
* ERPNext for enterprise resource planning
* Support for multiple sites and users
* Customizable and extensible
## Tech Stack
* Docker
* Docker Compose
* MariaDB
* ERPNext
* Python
## Installation
1. Clone the repository: `git clone https://github.com/your-username/literate-broccoli.git`
2. Navigate to the project directory: `cd literate-broccoli`
3. Build and start the containers: `docker-compose up -d`
## Usage
1. Access the ERPNext web interface: `http://localhost:8000`
2. Log in with the administrator credentials: `username: Administrator, password: admin`
## Required Environment Variables
* `DB_ROOT_PASSWORD`: The root password for the MariaDB database (default: `admin123`)
* `DB_PASSWORD`: The password for the ERPNext database user (default: `erpnext123`)
* `ADMIN_PASSWORD`: The password for the ERPNext administrator user (default: `admin`)
* `RAILWAY_PUBLIC_DOMAIN`: The public domain for the ERPNext site (default: `localhost`)