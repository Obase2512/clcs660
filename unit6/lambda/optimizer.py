import boto3, json, logging, os
from datetime import datetime, timedelta, timezone
from botocore.exceptions import ClientError

logger = logging.getLogger()
logger.setLevel(logging.INFO)

SAGEMAKER_ENDPOINT = os.environ["SAGEMAKER_ENDPOINT"]
ASG_NAME = os.environ["ASG_NAME"]
SNS_TOPIC_ARN = os.environ["SNS_TOPIC_ARN"]
DDB_TABLE = os.environ["DDB_TABLE"]

cw = boto3.client("cloudwatch")
sm = boto3.client("sagemaker-runtime")
asg = boto3.client("autoscaling")
sns = boto3.client("sns")
ddb = boto3.resource("dynamodb").Table(DDB_TABLE)

def lambda_handler(event, context):
    try:
        logger.info("🚀 Starting AI Resource Optimization cycle")

        end = datetime.now(timezone.utc)
        start = end - timedelta(days=90)
        metrics_response = cw.get_metric_data(
            MetricDataQueries=[{
                "Id": "cpu",
                "MetricStat": {
                    "Metric": {"Namespace": "AWS/EC2", "MetricName": "CPUUtilization"},
                    "Period": 3600,
                    "Stat": "Average"
                }
            }],
            StartTime=start, EndTime=end
        )
        datapoints = metrics_response.get("MetricDataResults", [{}])[0].get("Values", [])
        if not datapoints:
            logger.warning("No CloudWatch datapoints found")
            return {"status": "no_data"}

        payload = json.dumps({"instances": datapoints})
        response = sm.invoke_endpoint(EndpointName=SAGEMAKER_ENDPOINT, Body=payload, ContentType='application/json')
        forecast = json.loads(response["Body"].read().decode())

        if forecast.get("confidence", 0) > 0.75:
            asg.put_scaling_policy(
                AutoScalingGroupName=ASG_NAME,
                PolicyType="PredictiveScaling",
                PredictiveScalingConfiguration={
                    "MetricSpecifications": [{"TargetValue": 70}],
                    "Mode": "ForecastAndScale"
                }
            )
            logger.info("✅ Predictive scaling policy applied")

        rec = {
            "forecast_confidence": round(forecast.get("confidence", 0), 2),
            "savings_estimate": round(forecast.get("savings_estimate", 0), 2),
            "timestamp": datetime.now(timezone.utc).isoformat()
        }
        ddb.put_item(Item={"instance_id": "asg-optimizer", "timestamp": rec["timestamp"], "recommendation": rec})
        sns.publish(TopicArn=SNS_TOPIC_ARN, Subject="AI Optimization Complete", Message=json.dumps(rec, indent=2))

        return {"status": "success", "savings_estimate": rec["savings_estimate"]}

    except ClientError as e:
        logger.error(f"AWS Error: {str(e)}")
        sns.publish(TopicArn=SNS_TOPIC_ARN, Message=f"Optimizer failed: {str(e)}")
        raise
    except Exception as e:
        logger.exception("Unexpected error")
        raise