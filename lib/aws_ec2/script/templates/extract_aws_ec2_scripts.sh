#!/bin/bash -eux

# Downloads and extract the scripts.
# The extracted folder from github looks like this:
#   branch-name.tar.gz => aws-ec2-branch-name
#   master.tar.gz => aws-ec2-master
#   v1.0.0.tar.gz => aws-ec2-1.0.0
function extract_aws_ec2_scripts() {
  local temp_folder
  local url
  local filename

  rm -rf /opt/aws-ec2   # clean start

  temp_folder="/opt/aws-ec2-temp"
  rm -rf "$temp_folder"
  mkdir -p "$temp_folder"

  (
    cd "$temp_folder"

  <%
    # Examples:
    #   AWS_EC2_CODE=v1.0.0
    #   AWS_EC2_CODE=master
    #   AWS_EC2_CODE=branch-name
    #
    #   https://github.com/tongueroo/aws-ec2/archive/v1.0.0.tar.gz
    #   https://github.com/tongueroo/aws-ec2/archive/master.tar.gz
    code_version = ENV['AWS_EC2_CODE']
    code_version ||= "v#{AwsEc2::VERSION}"
  %>
    url="https://github.com/tongueroo/aws-ec2/archive/<%= code_version %>.tar.gz"
    filename=$(basename "$url")
    folder="${filename%.tar.gz}" # remove extension
    folder="${folder#v}" # remove leading v character
    folder="aws-ec2-$folder" # IE: aws-ec2-1.0.0

    wget "$url"
    tar zxf "$filename"

    mv "$temp_folder/$folder/lib/aws_ec2/scripts" /opt/aws-ec2
    rm -rf "$temp_folder"
    chmod a+x -R /opt/aws-ec2
  )
}

extract_aws_ec2_scripts