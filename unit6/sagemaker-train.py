#run this script after Terraform apply
import boto3
import sagemaker
from sagemaker.algorithms import DeepAR
from sagemaker import get_execution_role
import pandas as pd
import numpy as np
from datetime import datetime, timedelta

print("🚀 Training SageMaker DeepAR model (Unit 6 Report)...")

session = sagemaker.Session()
role = get_execution_role()

sts = boto3.client("sts")
account_id = sts.get_caller_identity()["Account"]
bucket = f"ai-enhanced-resource-optimization-dev-{account_id}-artifacts"

dates = pd.date_range(start=datetime.now() - timedelta(days=90), periods=2160, freq="H")
cpu = 40 + 20 * np.sin(np.linspace(0, 20, 2160)) + np.random.normal(0, 5, 2160)
df = pd.DataFrame({"timestamp": dates, "cpu": cpu})
df.to_csv("train.csv", index=False)

s3 = boto3.client("s3")
s3.upload_file("train.csv", bucket, "train/train.csv")
s3_uri = f"s3://{bucket}/train/train.csv"

estimator = DeepAR(
    role=role,
    instance_count=1,
    instance_type="ml.m5.large",
    time_frequency="H",
    prediction_length=168,
    context_length=336,
    epochs=20,
)

estimator.fit({"train": s3_uri}, wait=True)

predictor = estimator.deploy(
    initial_instance_count=1,
    instance_type="ml.t2.medium",
    endpoint_name="demand-forecast-endpoint"
)

print("✅ SageMaker DeepAR endpoint 'demand-forecast-endpoint' is READY!")
print("Next: Update Lambda environment variable SAGEMAKER_ENDPOINT = demand-forecast-endpoint")