FROM frappe/erpnext:v15.20.0

# Set working directory
WORKDIR /home/frappe/frappe-bench

# Expose port
EXPOSE 8000

# Set environment variables
ENV FRAPPE_SITE_NAME_HEADER=$RAILWAY_PUBLIC_DOMAIN

# Create startup script
RUN echo '#!/bin/bash\n\
set -e\n\
\n\
# Wait for database to be ready\n\
echo "Waiting for database..."\n\
until nc -z -v -w30 $DB_HOST $DB_PORT 2>/dev/null; do\n\
  echo "Waiting for database connection..."\n\
  sleep 2\n\
done\n\
echo "Database is ready!"\n\
\n\
# Check if site exists\n\
if [ ! -d "sites/$SITE_NAME" ]; then\n\
  echo "Creating new site: $SITE_NAME"\n\
  bench new-site $SITE_NAME \\\n\
    --mariadb-root-password=$DB_ROOT_PASSWORD \\\n\
    --admin-password=$ADMIN_PASSWORD \\\n\
    --db-host=$DB_HOST \\\n\
    --db-port=$DB_PORT \\\n\
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
# Start services\n\
echo "Starting Redis..."\n\
redis-server --daemonize yes --bind 0.0.0.0\n\
\n\
echo "Starting background workers..."\n\
bench worker --queue short,default,long &\n\
bench schedule &\n\
\n\
echo "Starting web server..."\n\
bench serve --port 8000 --host 0.0.0.0\n\
' > /home/frappe/start.sh && chmod +x /home/frappe/start.sh

# Run the startup script
CMD ["/bin/bash", "/home/frappe/start.sh"]