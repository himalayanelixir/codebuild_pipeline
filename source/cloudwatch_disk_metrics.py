"""This script reports disk useage of a CodeBuild container every 20 seconds
"""
import subprocess
import time
import boto3


def run_command(command_string):
    """Runs cli commands to retrieve local CodeBuild variables and disk use

    Args:
      command_string: String containing the cli command that will be executed

    Returns:
      Response string in utf-8 format
    """
    path_command = command_string
    response_raw = subprocess.run(
        [path_command], shell=True, capture_output=True, check=True
    )
    response = response_raw.stdout.decode("utf-8")
    return response


def cloudwatch_boto_call(name, build_id, build_number, project_name, unit, value):
    """Runs boto3 calls to create CloudWatch metrics

    Args:
      name: Name of the CloudWatch metric we are creating
      build_id: ID of the CodeBuild job
      build_number: Current build number for the CodeBuild project
      project_name: Name of the CodeBuild project
      unit: Unit of measurement
      value: Value of the metric we are measuring

    """
    cloudwatch = boto3.client("cloudwatch")
    response = cloudwatch.put_metric_data(
        MetricData=[
            {
                "MetricName": name,
                "Dimensions": [
                    {"Name": "BuildId", "Value": build_id},
                    {"Name": "BuildNumber", "Value": build_number},
                    {"Name": "ProjectName", "Value": project_name},
                ],
                "Unit": unit,
                "Value": value,
            },
        ],
        Namespace="DiskMetrics",
    )
    print(response)


def main():
    """Main funciton that retrieves data from local variables and from the system
    before pubmishing the metrics to CloudWatch.
    """

    codebuild_project_name_id = run_command("echo $CODEBUILD_BUILD_ID")
    codebuild_project_name, codebuild_build_id = codebuild_project_name_id.split(":")
    codebuild_build_id = codebuild_build_id.rstrip()

    codebuild_build_number = run_command("echo $CODEBUILD_BUILD_NUMBER")
    codebuild_build_number = codebuild_build_number.rstrip()

    while True:
        disk_usage = run_command("df --output=pcent /codebuild/output | tr -dc '0-9'")
        disk_usage = int(disk_usage)

        cloudwatch_boto_call(
            "DiskUsage",
            codebuild_build_id,
            codebuild_build_number,
            codebuild_project_name,
            "Percent",
            disk_usage,
        )
        time.sleep(20)


if __name__ == "__main__":
    main()
