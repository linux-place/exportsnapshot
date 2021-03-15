import os
import json
import boto3
from datetime import datetime
def get_db_snapshot():
    """
    Funtion to get the latest snapshot
    Returns: Latest snapshot
    """
    db_cluster_id = os.environ["DB_CLUSTER_ID"]
    
    client = boto3.client("rds")
    desc_cluster_snapshots = client.describe_db_cluster_snapshots(
                        DBClusterIdentifier=db_cluster_id,
                        SnapshotType="automated"
                        )
    desc_snapshots = client.describe_db_snapshots(
                        DBInstanceIdentifier=db_cluster_id,
                        SnapshotType="automated"
                        )
    db_snapshots = {}
    
    for snapshot in desc_cluster_snapshots["DBClusterSnapshots"]:
        db_snapshots.update([(snapshot["DBClusterSnapshotArn"], snapshot["SnapshotCreateTime"])])
    for snapshot in desc_snapshots["DBSnapshots"]:
        db_snapshots.update([(snapshot["DBSnapshotArn"], snapshot["SnapshotCreateTime"])])
    print ("Exporting {}".format(db_cluster_id))
    return (max(db_snapshots.items()))
    
    
def jsondatetimeconverter(o):
    """To avoid TypeError: datetime.datetime(...) is not JSON serializable"""
    if isinstance(o, datetime):
        return o.__str__()
    
def instantiate_s3_export(event, context):
    """
    Function to invoke start_export_task using
    recent most system snapshot
    Return: Response 
    """
    
    s3_bucket = os.environ["S3_BUCKET"]
    iam_role = os.environ["IAM_ROLE"]
    kms_key = os.environ["KMS_KEY"]
    export_identifier = os.environ["EXPORT_ID"]
    if "S3_PREFIX" in os.environ:
        s3_prefix = os.environ["S3_PREFIX"]
    else:
        s3_prefix = os.environ["DB_CLUSTER_ID"]

    if ("TABLE_LIST" in os.environ) and len(os.environ["TABLE_LIST"]) > 1:
        tables = os.environ["TABLE_LIST"]
        tables = json.loads(tables)
    else:
        tables = ""
    client = boto3.client("rds")
        
    get_latest_snapshot_name,get_latest_snapshot_time  = get_db_snapshot()
    print ("Snapshot: {}\n Now: {}".format(get_latest_snapshot_time.date(),datetime.today().date() ))
    if get_latest_snapshot_time.date() == datetime.today().date():
        today_date = datetime.today().strftime("%Y-%m-%d")
        export_task = export_identifier+"-"+today_date
        
        if len(tables) > 0 :
            response = client.start_export_task(
                    ExportTaskIdentifier=export_task,
                    SourceArn=get_latest_snapshot_name,
                    S3BucketName=s3_bucket,
                    S3Prefix=s3_prefix,
                    IamRoleArn=iam_role,
                    KmsKeyId=kms_key,
                    ExportOnly=tables
            )
        else:
            response = client.start_export_task(
                    ExportTaskIdentifier=export_task,
                    SourceArn=get_latest_snapshot_name,
                    S3BucketName=s3_bucket,
                    S3Prefix=s3_prefix,
                    IamRoleArn=iam_role,
                    KmsKeyId=kms_key
                )
            
        return(json.dumps(response, default=jsondatetimeconverter))
    else:
        return(f"Not invoking start export task as the backup its not the latest backup.\n{get_latest_snapshot_time.date()} {datetime.today().date()}")