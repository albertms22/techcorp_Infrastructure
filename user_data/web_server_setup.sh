#!/bin/bash
# Web Server Setup Script for Apache

# Update system packages
yum update -y

# Install Apache web server
yum install -y httpd

# Get instance metadata
INSTANCE_ID=$(ec2-metadata --instance-id | cut -d " " -f 2)
AVAILABILITY_ZONE=$(ec2-metadata --availability-zone | cut -d " " -f 2)
PRIVATE_IP=$(ec2-metadata --local-ipv4 | cut -d " " -f 2)

# Create a custom HTML page
cat > /var/www/html/index.html <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>TechCorp Web Server</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 800px;
            margin: 50px auto;
            padding: 20px;
            background-color: #f0f0f0;
        }
        .container {
            background-color: white;
            border-radius: 10px;
            padding: 30px;
            box-shadow: 0 2px 10px rgba(0,0,0,0.1);
        }
        h1 {
            color: #2c3e50;
            border-bottom: 3px solid #3498db;
            padding-bottom: 10px;
        }
        .info {
            background-color: #ecf0f1;
            padding: 15px;
            border-radius: 5px;
            margin: 10px 0;
        }
        .label {
            font-weight: bold;
            color: #34495e;
        }
        .value {
            color: #2980b9;
            font-family: monospace;
        }
        .status {
            color: #27ae60;
            font-weight: bold;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 TechCorp Web Application</h1>
        <p class="status">✓ Server is running successfully!</p>
        
        <div class="info">
            <p><span class="label">Instance ID:</span> <span class="value">$INSTANCE_ID</span></p>
            <p><span class="label">Availability Zone:</span> <span class="value">$AVAILABILITY_ZONE</span></p>
            <p><span class="label">Private IP:</span> <span class="value">$PRIVATE_IP</span></p>
            <p><span class="label">Server Type:</span> <span class="value">Apache Web Server</span></p>
        </div>
        
        <p style="margin-top: 20px; color: #7f8c8d; font-size: 14px;">
            This page is served from an EC2 instance behind an Application Load Balancer.
        </p>
    </div>
</body>
</html>
EOF

# Start and enable Apache
systemctl start httpd
systemctl enable httpd

# Configure firewall (if needed)
# Allow HTTP traffic
if command -v firewall-cmd &> /dev/null; then
    firewall-cmd --permanent --add-service=http
    firewall-cmd --reload
fi

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

# Ensure PasswordAuthentication is disabled for security (do NOT enable password auth)
sed -i 's/PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
sed -i 's/#PasswordAuthentication no/PasswordAuthentication no/' /etc/ssh/sshd_config
systemctl restart sshd

# Add techcorp user to sudoers with limited privileges
# Allow only specific administrative commands for web server management
cat > /etc/sudoers.d/techcorp <<'SUDOERS'
# techcorp user - Limited sudo access for web server administration
techcorp ALL=(ALL) /usr/sbin/apachectl, /bin/systemctl restart httpd, /bin/systemctl stop httpd, /bin/systemctl start httpd, /bin/systemctl status httpd
SUDOERS

chmod 0440 /etc/sudoers.d/techcorp

# Create a health check endpoint
cat > /var/www/html/health.html <<EOF
OK
EOF

# Log completion
echo "Web server setup completed at $(date)" >> /var/log/user-data.log
