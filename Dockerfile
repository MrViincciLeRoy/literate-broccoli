FROM frappe/erpnext:v15.20.0

# Set working directory
WORKDIR /home/frappe/frappe-bench

# Install netcat for health checks
USER root
RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*
USER frappe

# Expose port
EXPOSE 8000

# Create startup script with embedded MariaDB
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Start MariaDB as root\n\
sudo service mariadb start\n\
\n\
# Wait for MariaDB to be ready\n\
echo "Waiting for MariaDB to start..."\n\
for i in {1..30}; do\n\
  if sudo mysqladmin ping -h localhost --silent; then\n\
    echo "MariaDB is ready!"\n\
    break\n\
  fi\n\
  echo "Waiting... ($i/30)"\n\
  sleep 2\n\
done\n\
\n\
# Set MariaDB root password\n\
sudo mysql -e "ALTER USER '\''root'\''@'\''localhost'\'' IDENTIFIED BY '\''${DB_ROOT_PASSWORD}'\'';" || true\n\
sudo mysql -e "FLUSH PRIVILEGES;" || true\n\
\n\
# Use Railway public domain or fallback\n\
SITE_NAME="${RAILWAY_PUBLIC_DOMAIN:-localhost}"\n\
echo "Site name: $SITE_NAME"\n\
\n\
# Check if site exists\n\
if [ ! -d "sites/$SITE_NAME" ]; then\n\
  echo "Creating new site: $SITE_NAME"\n\
  bench new-site $SITE_NAME \\\n\
    --mariadb-root-password="${DB_ROOT_PASSWORD}" \\\n\
    --admin-password="${ADMIN_PASSWORD}" \\\n\
    --no-mariadb-socket\n\
  \n\
  echo "Installing ERPNext app..."\n\
  bench --site $SITE_NAME install-app erpnext\n\
  \n\
  echo "Setting up scheduler..."\n\
  bench --site $SITE_NAME scheduler enable\n\
fi\n\
\n\
# Set site in currentsite.txt\n\
echo $SITE_NAME > sites/currentsite.txt\n\
\n\
# Start Redis\n\
echo "Starting Redis..."\n\
redis-server --daemonize yes --bind 127.0.0.1\n\
\n\
# Start background workers\n\
echo "Starting background workers..."\n\
bench worker --queue short,default,long &\n\
bench schedule &\n\
\n\
# Start web server\n\
echo "Starting web server on port 8000..."\n\
bench serve --port 8000 --host 0.0.0.0\n\
' > /home/frappe/start.sh && chmod +x /home/frappe/start.sh

# Give sudo access for MariaDB
USER root
RUN echo "frappe ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
USER frappe

# Run the startup script
CMD ["/bin/bash", "/home/frappe/start.sh"]
