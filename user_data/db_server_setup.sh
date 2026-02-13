#!/bin/bash
# Database Server Setup Script for PostgreSQL

# Update system packages
yum update -y

# Install PostgreSQL
amazon-linux-extras enable postgresql14
yum install -y postgresql postgresql-server

# Initialize PostgreSQL database
postgresql-setup initdb

# Configure PostgreSQL to accept connections from web servers
# Backup original configuration
cp /var/lib/pgsql/data/postgresql.conf /var/lib/pgsql/data/postgresql.conf.backup
cp /var/lib/pgsql/data/pg_hba.conf /var/lib/pgsql/data/pg_hba.conf.backup

# Configure PostgreSQL to listen on all interfaces
sed -i "s/#listen_addresses = 'localhost'/listen_addresses = '*'/" /var/lib/pgsql/data/postgresql.conf

# Allow connections from the VPC CIDR range (10.0.0.0/16)
cat >> /var/lib/pgsql/data/pg_hba.conf <<EOF

# Allow connections from VPC
host    all             all             10.0.0.0/16             md5
EOF

# Start and enable PostgreSQL
systemctl start postgresql
systemctl enable postgresql

# Wait for PostgreSQL to be ready
sleep 5

# Retrieve database password from secure source
# Priority order:
# 1. Environment variable TECHCORP_DB_PASSWORD (provided at runtime)
# 2. AWS Secrets Manager secret named 'techcorp-db-password'
# For this example, we use an environment variable that must be set at instance launch

if [ -z "$TECHCORP_DB_PASSWORD" ]; then
    echo "ERROR: TECHCORP_DB_PASSWORD environment variable is not set" >&2
    echo "Please provide the database password via environment variable or AWS Secrets Manager" >&2
    exit 1
fi

# Create database and user with password from secure source
sudo -u postgres psql <<EOF
-- Create a database
CREATE DATABASE techcorp_db;

-- Create a user with password retrieved from secure source
CREATE USER techcorp_user WITH PASSWORD '$TECHCORP_DB_PASSWORD';

-- Grant privileges
GRANT ALL PRIVILEGES ON DATABASE techcorp_db TO techcorp_user;

-- Create a sample table
\c techcorp_db
CREATE TABLE IF NOT EXISTS users (
    id SERIAL PRIMARY KEY,
    username VARCHAR(50) NOT NULL,
    email VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert sample data
INSERT INTO users (username, email) VALUES 
    ('admin', 'admin@techcorp.com'),
    ('user1', 'user1@techcorp.com'),
    ('user2', 'user2@techcorp.com');

-- Grant table permissions
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public TO techcorp_user;
GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public TO techcorp_user;
EOF

# Create a user for SSH access with key-based authentication
useradd -m -s /bin/bash techcorp

# Set up SSH directory and authorized_keys
mkdir -p /home/techcorp/.ssh
chmod 700 /home/techcorp/.ssh

# Note: SSH public key should be provided via:
# - User data environment variable TECHCORP_PUBLIC_KEY
# - AWS Systems Manager Parameter Store
# - AWS Secrets Manager
# For now, the key must be provisioned by the infrastructure/deployment system
if [ -n "$TECHCORP_PUBLIC_KEY" ]; then
    echo "$TECHCORP_PUBLIC_KEY" >> /home/techcorp/.ssh/authorized_keys
    chmod 600 /home/techcorp/.ssh/authorized_keys
    chown -R techcorp:techcorp /home/techcorp/.ssh
fi

# Ensure PasswordAuthentication is disabled for security
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication no/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Add techcorp user to sudoers with limited privileges
# Allow only specific administrative commands
cat > /etc/sudoers.d/techcorp <<'SUDOERS'
# techcorp user - Limited sudo access for database administration
techcorp ALL=(ALL) NOPASSWD: /bin/systemctl restart postgresql, /bin/systemctl stop postgresql, /bin/systemctl start postgresql, /bin/systemctl status postgresql
techcorp ALL=(ALL) /usr/bin/psql, /usr/bin/pg_dump
SUDOERS

chmod 0440 /etc/sudoers.d/techcorp

# Create a connection test script
cat > /home/techcorp/test_db_connection.sh <<'SCRIPT'
#!/bin/bash
echo "Testing PostgreSQL connection..."
psql -h localhost -U techcorp_user -d techcorp_db -c "SELECT * FROM users;"
SCRIPT

chmod +x /home/techcorp/test_db_connection.sh
chown techcorp:techcorp /home/techcorp/test_db_connection.sh

# Create README for database access
cat > /home/techcorp/DATABASE_INFO.txt <<EOF
===========================================
TechCorp Database Server Information
===========================================

PostgreSQL Version: $(psql --version)
Database Name: techcorp_db
Database User: techcorp_user

IMPORTANT: Database password must be retrieved from a secure credential store:
- AWS Secrets Manager: Retrieve from the 'techcorp-db-password' secret
- AWS SSM Parameter Store: Retrieve from '/techcorp/db/password' parameter
- Environment Variable: Read from TECHCORP_DB_PASSWORD at runtime

Connection from web servers:
psql -h $(hostname -I | awk '{print $1}') -U techcorp_user -d techcorp_db

Connection test:
./test_db_connection.sh

Sample queries (requires password authentication):
psql -h localhost -U techcorp_user -d techcorp_db -c "SELECT * FROM users;"

SECURITY NOTE: Never store database passwords in files or logs.
Always use secure credential management services.

===========================================
EOF

chmod 0640 /home/techcorp/DATABASE_INFO.txt
chown techcorp:techcorp /home/techcorp/DATABASE_INFO.txt

# Log completion
echo "Database server setup completed at $(date)" >> /var/log/user-data.log
echo "PostgreSQL is running and configured" >> /var/log/user-data.log
