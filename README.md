# TechCorp AWS Infrastructure

## Architecture Overview

The infrastructure includes:
- VPC with public and private subnets across 2 availability zones
- Internet Gateway and NAT Gateways for network connectivity
- Bastion host for secure administrative access
- 2 Web servers running Apache behind an Application Load Balancer
- 1 Database server running PostgreSQL
- Proper security groups for network isolation

## Prerequisites

Before you begin, ensure you have the following:

1. **AWS Account** with appropriate permissions
2. **AWS CLI** installed and configured
   ```bash
   aws configure
   ```
3. **Terraform** installed (version >= 1.0)
   ```bash
   # Download from https://www.terraform.io/downloads
   terraform --version
   ```
4. **SSH Key Pair** created in your AWS region
   ```bash
   # Create a key pair in AWS Console or via CLI:
   aws ec2 create-key-pair --key-name techcorp-key --query 'KeyMaterial' --output text > techcorp-key.pem
   chmod 400 techcorp-key.pem
   ```
5. **Your Public IP Address**
   ```bash
   # Find your IP:
   curl ifconfig.me
   ```

## Project Structure

```
terraform-assessment/
├── main.tf                          # Main Terraform configuration
├── variables.tf                     # Variable declarations
├── outputs.tf                       # Output definitions
├── terraform.tfvars.example         # Example variables file
├── user_data/
│   ├── web_server_setup.sh         # Web server initialization script
│   └── db_server_setup.sh          # Database server initialization script
└── README.md                        # This file
```

## Setup Instructions

### Step 1: Clone and Configure

1. Copy the example variables file:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

2. Edit `terraform.tfvars` with your actual values:
   ```hcl
   aws_region    = "us-east-1"
   my_ip         = "YOUR.PUBLIC.IP.ADDRESS/32"  # Replace with your IP
   key_pair_name = "techcorp-key"                # Your AWS key pair name
   server_password = "YourSecurePassword123!"    # Change this!
   ```

### Step 2: Initialize Terraform

```bash
# Initialize Terraform and download providers
terraform init
```

### Step 3: Review the Plan

```bash
# See what Terraform will create
terraform plan
```

This will show you all the resources that will be created. Review carefully!

### Step 4: Deploy Infrastructure

```bash
# Deploy the infrastructure
terraform apply
```

Type `yes` when prompted to confirm.

**Note:** Deployment takes approximately 5-10 minutes.

### Step 5: Get Outputs

```bash
# View important information about your deployment
terraform output
```

Save these outputs! You'll need them to access your infrastructure.

## Accessing Your Infrastructure

### 1. Access Bastion Host

**Option A: Using SSH Key**
```bash
ssh -i techcorp-key.pem ec2-user@<BASTION_PUBLIC_IP>
```

**Option B: Using Password**
```bash
ssh techcorp@<BASTION_PUBLIC_IP>
# Password: The one you set in terraform.tfvars
```

### 2. Access Web Servers from Bastion

Once on the bastion host:

```bash
# SSH to web server 1
ssh techcorp@<WEB_SERVER_1_PRIVATE_IP>
# Password: TechCorp2024!Secure (or your configured password)

# SSH to web server 2
ssh techcorp@<WEB_SERVER_2_PRIVATE_IP>
```

### 3. Access Database Server from Bastion

```bash
# SSH to database server
ssh techcorp@<DATABASE_PRIVATE_IP>

# Once on the database server, test PostgreSQL
psql -h localhost -U techcorp_user -d techcorp_db
# Password: TechCorp2024!DB

# Run a test query
SELECT * FROM users;
```

### 4. Access Web Application

Open your browser and visit:
```
http://<LOAD_BALANCER_DNS_NAME>
```

The page will show which instance is serving your request.

## Testing the Infrastructure

### Test 1: Verify Load Balancer

```bash
# The ALB should distribute traffic between both web servers
# Refresh the page multiple times to see different instance IDs
curl http://<LOAD_BALANCER_DNS_NAME>
```

### Test 2: Verify Database Connectivity

From bastion, SSH to a web server, then test database connection:

```bash
# Install PostgreSQL client on web server
sudo yum install -y postgresql

# Connect to database server
psql -h <DATABASE_PRIVATE_IP> -U techcorp_user -d techcorp_db

# Test query
SELECT * FROM users;
```

### Test 3: Verify High Availability

The infrastructure spans 2 availability zones:
- Public subnets in 2 AZs
- Private subnets in 2 AZs
- Web servers distributed across AZs
- NAT Gateways in both AZs

## Important Security Notes

⚠️ **Security Considerations:**

1. **SSH Access**: Bastion host only accepts SSH from your IP address
2. **Password Authentication**: Enabled for ease of use (can be disabled for production)
3. **Database Access**: Only accessible from web servers and bastion
4. **Web Access**: Load balancer is publicly accessible on ports 80/443
5. **Secrets**: Never commit `terraform.tfvars` or `terraform.tfstate` to version control

## Troubleshooting

### Issue: Cannot SSH to Bastion
- Verify your IP in terraform.tfvars matches your current IP
- Check security group rules in AWS Console
- Verify key pair permissions: `chmod 400 techcorp-key.pem`

### Issue: Cannot Access Web Application
- Wait 5 minutes after deployment for instances to fully initialize
- Check target group health in AWS Console (EC2 → Target Groups)
- Verify security groups allow HTTP traffic

### Issue: Database Connection Fails
- Ensure you're connecting from web server or bastion
- Check PostgreSQL is running: `sudo systemctl status postgresql`
- Verify pg_hba.conf allows connections from VPC

### View User Data Logs
```bash
# On any EC2 instance, check user-data execution logs
sudo cat /var/log/cloud-init-output.log
sudo cat /var/log/user-data.log
```

## Monitoring Resources

### Check Resource Status

```bash
# VPC and Subnets
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=techcorp-vpc"
aws ec2 describe-subnets --filters "Name=vpc-id,Values=<VPC_ID>"

# EC2 Instances
aws ec2 describe-instances --filters "Name=tag:Name,Values=techcorp-*"

# Load Balancer
aws elbv2 describe-load-balancers --names techcorp-web-alb

# Target Group Health
aws elbv2 describe-target-health --target-group-arn <TARGET_GROUP_ARN>
```

## Cleanup Instructions

⚠️ **Important:** This will destroy all resources and cannot be undone!

### Option 1: Terraform Destroy

```bash
# Destroy all resources
terraform destroy
```

Type `yes` when prompted.

### Option 2: Manual Cleanup (if Terraform fails)

If `terraform destroy` fails, manually delete in this order:
1. EC2 Instances
2. Load Balancer
3. Target Groups
4. NAT Gateways
5. Elastic IPs
6. Internet Gateway
7. Subnets
8. VPC

### Verify Cleanup

```bash
# Check for remaining resources
aws ec2 describe-vpcs --filters "Name=tag:Name,Values=techcorp-vpc"
```

## Cost Estimation

Approximate monthly costs (us-east-1):
- EC2 Instances (4x t3.micro, 1x t3.small): ~$35/month
- NAT Gateways (2x): ~$65/month
- Application Load Balancer: ~$23/month
- Data Transfer: Varies based on usage
- **Total: ~$123/month**

💡 **Tip:** Run `terraform destroy` when not in use to avoid charges!

## Submission Checklist

- [ ] All Terraform files created and organized
- [ ] Infrastructure successfully deployed
- [ ] Screenshot: `terraform plan` output
- [ ] Screenshot: `terraform apply` completion
- [ ] Screenshot: AWS Console showing VPC and subnets
- [ ] Screenshot: AWS Console showing EC2 instances
- [ ] Screenshot: AWS Console showing Load Balancer
- [ ] Screenshot: Web page served through ALB (showing instance ID)
- [ ] Screenshot: SSH to bastion host
- [ ] Screenshot: SSH from bastion to web server
- [ ] Screenshot: SSH from bastion to database server
- [ ] Screenshot: PostgreSQL connection and query results
- [ ] Export terraform.tfstate (ensure no sensitive data)
- [ ] Create GitHub repository: `month-one-assessment`
- [ ] Upload all files following required structure

## Evidence Screenshots Guide

### 1. Terraform Plan
```bash
terraform plan > plan_output.txt
# Take screenshot of the plan summary
```

### 2. Terraform Apply
```bash
terraform apply
# Screenshot showing "Apply complete! Resources: XX added"
```

### 3. AWS Console Screenshots
- EC2 Dashboard showing all instances running
- VPC Dashboard showing subnets
- Load Balancer showing healthy targets
- Security Groups showing proper rules

### 4. Application Access
- Browser showing ALB URL with instance ID visible
- Refresh page to show different instance ID (load balancing)

### 5. SSH Access Chain
```bash
# Terminal 1: SSH to bastion
ssh -i techcorp-key.pem ec2-user@<BASTION_IP>

# Terminal 2: From bastion to web server
ssh techcorp@<WEB_PRIVATE_IP>

# Terminal 3: From bastion to database
ssh techcorp@<DB_PRIVATE_IP>
psql -h localhost -U techcorp_user -d techcorp_db -c "SELECT * FROM users;"
```

## Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS VPC Documentation](https://docs.aws.amazon.com/vpc/)
- [AWS EC2 Documentation](https://docs.aws.amazon.com/ec2/)
- [AWS ELB Documentation](https://docs.aws.amazon.com/elasticloadbalancing/)

## Support

For issues or questions:
1. Check the Troubleshooting section above
2. Review Terraform error messages carefully
3. Check AWS CloudWatch logs for instance initialization errors
4. Verify all prerequisites are met

## License

This is an assessment project for educational purposes.

---

**Created for:** TechCorp Month 1 Assessment  
**Date:** February 2026  
**Infrastructure as Code:** Terraform  
**Cloud Provider:** AWS
