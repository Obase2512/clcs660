# Deployment Guide

# 1. Deploy the Infrastructure with optimizer script (VPC, ASG, IAM, Lambda, DynamoDB, SNS, S3, KMS, and EventBridge.)
- Generate ai optimizer script (optimizer.py)
- reference ai optimizer script in the main deployment terraform script (main.tf)
- Review and update `terraform.tfvars`
- Run `terraform init`.
- Run `terraform plan`.
- Run `terraform apply -auto-approve`.

# 2. Train the SageMaker model (run this script after terraform apply)
Run `python sagemaker-train.py`

3. In AWS Console → Lambda → your function → Environment variables → set SAGEMAKER_ENDPOINT = demand-forecast-endpoint → Save

4. Delete the SageMaker endpoint manually through the console or AWS CLI when you are done, as terraform destroy will not catch resources created by a Python script!

# 5. Test
- Browse the demo app URL
- Manually invoke Lambda once
- Check SNS email, DynamoDB, CloudWatch logs

6. Clean up by running `terraform destroy -auto-approve` after testing is complete.
