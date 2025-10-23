#dockerfile
FROM frappe/erpnext:v15.20.0

# Switch to root to install dependencies and configure MariaDB
USER root

# Install required packages
RUN apt-get update && \
    apt-get install -y netcat-openbsd sudo mariadb-server redis-server && \
    rm -rf /var/lib/apt/lists/*

# Configure MariaDB to allow root login without password initially
RUN mkdir -p /var/run/mysqld && \
    chown -R mysql:mysql /var/run/mysqld && \
    chmod 777 /var/run/mysqld

# Give frappe user sudo access
RUN echo "frappe ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

# Switch back to frappe user
USER frappe

# Set working directory
WORKDIR /home/frappe/frappe-bench

# Expose port
EXPOSE 8000

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
echo "Starting MariaDB..."\n\
sudo service mariadb start\n\
\n\
# Wait for MariaDB to be ready\n\
echo "Waiting for MariaDB to start..."\n\
for i in {1..30}; do\n\
  if sudo mysqladmin ping -h localhost --silent 2>/dev/null; then\n\
    echo "MariaDB is ready!"\n\
    break\n\
  fi\n\
  echo "Waiting... ($i/30)"\n\
  sleep 2\n\
done\n\
\n\
# Set MariaDB root password\n\
echo "Configuring MariaDB root password..."\n\
sudo mysql -e "ALTER USER '\''root'\''@'\''localhost'\'' IDENTIFIED BY '\''${DB_ROOT_PASSWORD}'\'';" 2>/dev/null || \\\n\
sudo mysqladmin -u root password "${DB_ROOT_PASSWORD}" 2>/dev/null || \\\n\
echo "Password already set or error occurred"\n\
\n\
sudo mysql -u root -p"${DB_ROOT_PASSWORD}" -e "FLUSH PRIVILEGES;" 2>/dev/null || true\n\
\n\
# Determine site name\n\
if [ -n "$RAILWAY_PUBLIC_DOMAIN" ]; then\n\
  SITE_NAME="$RAILWAY_PUBLIC_DOMAIN"\n\
else\n\
  SITE_NAME="localhost"\n\
fi\n\
\n\
echo "Site name will be: $SITE_NAME"\n\
\n\
# Check if site exists\n\
if [ ! -d "sites/$SITE_NAME" ]; then\n\
  echo "Creating new site: $SITE_NAME"\n\
  bench new-site $SITE_NAME \\\n\
    --mariadb-root-password="${DB_ROOT_PASSWORD}" \\\n\
    --admin-password="${ADMIN_PASSWORD}" \\\n\
    --no-mariadb-socket \\\n\
    --verbose\n\
  \n\
  echo "Installing ERPNext app..."\n\
  bench --site $SITE_NAME install-app erpnext\n\
  \n\
  echo "Enabling scheduler..."\n\
  bench --site $SITE_NAME scheduler enable\n\
  \n\
  echo "Site setup complete!"\n\
else\n\
  echo "Site already exists: $SITE_NAME"\n\
fi\n\
\n\
# Set current site\n\
echo $SITE_NAME > sites/currentsite.txt\n\
\n\
# Start Redis\n\
echo "Starting Redis..."\n\
sudo service redis-server start || redis-server --daemonize yes --bind 127.0.0.1 || echo "Redis already running"\n\
\n\
# Wait for Redis\n\
sleep 2\n\
\n\
# Start background workers\n\
echo "Starting background workers..."\n\
bench worker --queue short,default,long > /tmp/worker.log 2>&1 &\n\
bench schedule > /tmp/schedule.log 2>&1 &\n\
\n\
# Give workers time to start\n\
sleep 2\n\
\n\
# Start web server\n\
echo ""\n\
echo "======================================"\n\
echo "ERPNext is starting..."\n\
echo "Site: $SITE_NAME"\n\
echo "Admin User: Administrator"\n\
echo "Admin Password: $ADMIN_PASSWORD"\n\
echo "======================================"\n\
echo ""\n\
\n\
bench serve --port 8000 --noreload --nothreading\n\
' > /home/frappe/start.sh && chmod +x /home/frappe/start.sh

# Set environment defaults
ENV ADMIN_PASSWORD=admin
ENV DB_ROOT_PASSWORD=admin123

# Run the startup script
CMD ["/bin/bash", "/home/frappe/start.sh"]
