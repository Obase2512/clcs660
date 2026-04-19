# AI-Enhanced Cloud Automation for Intelligent Resource Optimization

This project deploys a small AWS environment that hosts a demo application on EC2 and a semi-automated optimization workflow that analyzes CloudWatch CPU trends, stores recommendations in DynamoDB, and notifies stakeholders through SNS.

## Architecture

- **EC2**: Hosts the demo application (nginx)
- **CloudWatch**: Provides CPU utilization metrics
- **Lambda**: Analyzes utilization and creates optimization recommendations
- **DynamoDB**: Stores the recommendation history
- **SNS**: Sends optimization notifications
- **S3 + KMS**: Secure storage for artifacts/evidence
- **EventBridge**: Runs the optimization analysis on a schedule

## Prerequisites

- AWS account
- AWS CLI configured locally
- Terraform >= 1.5
- An email address for SNS subscription, optional but recommended

## Deployment Steps

1. Configure the AWS CLI: Use individual values in your AWS service client, and copy  your AWS access key ID, AWS secret access key, and AWS session token to terraform variables

2. Install Terraform from the Command Line (e.g Cloudshell)
   
      sudo yum install -y yum-utils
   
      curl -O https://releases.hashicorp.com/terraform/1.5.7/terraform_1.5.7_linux_amd64.zip
   
      unzip terraform_1.5.7_linux_amd64.zip
   
      sudo mv terraform /usr/local/bin/
   
      terraform -v

4. Update `terraform.tfvars` if needed:
   ```hcl
   aws_region         = "us-east-1"
   notification_email = "your-email@example.com"
   ec2_instance_type  = "t3.micro"
   ```

5. Initialize Terraform:
   terraform init

6. Review the plan:
   terraform plan

7. Deploy the stack:
   terraform apply

8. Confirm the SNS subscription from your email inbox.

9. Open the demo application using the Terraform output `demo_app_url`.

10. Wait for the scheduled Lambda run, or invoke it manually from the Lambda console to generate recommendations.

## Validation

- Confirm the VPC → ASG with sample app and serves the nginx demo page.
- Confirm Lambda logs show a completed analysis.
- Confirm DynamoDB contains a recommendation record.
- Confirm SNS delivered a notification.

## Cleanup

```bash
terraform destroy
```
