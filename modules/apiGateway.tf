# Create S3 Full Access Policy
resource "aws_iam_policy" "s3_policy" {
  name        = "s3-policy"
  description = "Policy for allowing all S3 Actions"

  policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": "s3:*",
            "Resource": "*"
        }
    ]
}
EOF
}

# Create API Gateway Role
resource "aws_iam_role" "s3_api_gateway_role" {
  name = "s3-api-gateway-role"

  # Create Trust Policy for API Gateway
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "apigateway.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

# Attach S3 Access Policy to the API Gateway Role
resource "aws_iam_role_policy_attachment" "s3_policy_attach" {
  role       = aws_iam_role.s3_api_gateway_role.name
  policy_arn = aws_iam_policy.s3_policy.arn
}

resource "aws_api_gateway_rest_api" "S3Api" {
  name        = var.apiGatewayName
  description = "API for S3 Integration"

}

resource "aws_api_gateway_resource" "Folder" {
  rest_api_id = aws_api_gateway_rest_api.S3Api.id
  parent_id   = aws_api_gateway_rest_api.S3Api.root_resource_id
  path_part   = "{folder}"
}

resource "aws_api_gateway_resource" "Object" {
  rest_api_id = aws_api_gateway_rest_api.S3Api.id
  parent_id   = aws_api_gateway_resource.Folder.id
  path_part   = "{object}"
}

resource "aws_api_gateway_method" "PutBuckets" {
  rest_api_id   = aws_api_gateway_rest_api.S3Api.id
  resource_id   = aws_api_gateway_resource.Object.id
  http_method   = "PUT"
  authorization = "NONE"
  api_key_required = true
  request_parameters = {
    "method.request.path.folder" = true
    "method.request.path.object" = true
  }
}

resource "aws_api_gateway_integration" "S3Integration" {
  rest_api_id = aws_api_gateway_rest_api.S3Api.id
  resource_id = aws_api_gateway_resource.Object.id
  http_method = aws_api_gateway_method.PutBuckets.http_method
  integration_http_method = "PUT"
  type = "AWS"
  uri         = "arn:aws:apigateway:${var.aws_region}:s3:path/${var.s3BucketName}/{folder}/{object}"
  credentials = aws_iam_role.s3_api_gateway_role.arn

  request_parameters = {
    "integration.request.path.folder" = "method.request.path.folder"
    "integration.request.path.object" = "method.request.path.object"
  }

  depends_on  = [aws_s3_bucket.s3Buckets]

}

resource "aws_api_gateway_method_response" "Status200" {
  rest_api_id = aws_api_gateway_rest_api.S3Api.id
  resource_id = aws_api_gateway_resource.Object.id
  http_method = aws_api_gateway_method.PutBuckets.http_method
  status_code = "200"

  response_parameters = {
    "method.response.header.Timestamp"      = true
    "method.response.header.Content-Length" = true
    "method.response.header.Content-Type"   = true
  }

  response_models = {
    "application/json" = "Empty"
  }
}

resource "aws_api_gateway_method_response" "Status400" {
  depends_on = [aws_api_gateway_integration.S3Integration]

  rest_api_id = aws_api_gateway_rest_api.S3Api.id
  resource_id = aws_api_gateway_resource.Object.id
  http_method = aws_api_gateway_method.PutBuckets.http_method
  status_code = "400"
}

resource "aws_api_gateway_method_response" "Status500" {
  depends_on = [aws_api_gateway_integration.S3Integration]

  rest_api_id = aws_api_gateway_rest_api.S3Api.id
  resource_id = aws_api_gateway_resource.Object.id
  http_method = aws_api_gateway_method.PutBuckets.http_method
  status_code = "500"
}

resource "aws_api_gateway_integration_response" "IntegrationResponse200" {
  depends_on = [aws_api_gateway_integration.S3Integration]

  rest_api_id = aws_api_gateway_rest_api.S3Api.id
  resource_id = aws_api_gateway_resource.Object.id
  http_method = aws_api_gateway_method.PutBuckets.http_method
  status_code = aws_api_gateway_method_response.Status200.status_code

  response_parameters = {
    "method.response.header.Timestamp"      = "integration.response.header.Date"
    "method.response.header.Content-Length" = "integration.response.header.Content-Length"
    "method.response.header.Content-Type"   = "integration.response.header.Content-Type"
  }
}

resource "aws_api_gateway_integration_response" "IntegrationResponse400" {
  depends_on = [aws_api_gateway_integration.S3Integration]

  rest_api_id = aws_api_gateway_rest_api.S3Api.id
  resource_id = aws_api_gateway_resource.Object.id
  http_method = aws_api_gateway_method.PutBuckets.http_method
  status_code = aws_api_gateway_method_response.Status400.status_code

  selection_pattern = "4\\d{2}"
}

resource "aws_api_gateway_integration_response" "IntegrationResponse500" {
  depends_on = [aws_api_gateway_integration.S3Integration]

  rest_api_id = aws_api_gateway_rest_api.S3Api.id
  resource_id = aws_api_gateway_resource.Object.id
  http_method = aws_api_gateway_method.PutBuckets.http_method
  status_code = aws_api_gateway_method_response.Status500.status_code

  selection_pattern = "5\\d{2}"
}

resource "aws_api_gateway_deployment" "S3APIDeployment" {
  depends_on  = [aws_api_gateway_integration.S3Integration]
  rest_api_id = aws_api_gateway_rest_api.S3Api.id
  stage_name  = "dev"
}

resource "aws_api_gateway_usage_plan" "digitecchusageplan" {
  name = "my_usage_plan"

  api_stages {
    api_id = aws_api_gateway_rest_api.S3Api.id
    stage  = aws_api_gateway_deployment.S3APIDeployment.stage_name
  }
}

resource "aws_api_gateway_api_key" "digitechkey" {
  name = var.apiKeyName
}

resource "aws_api_gateway_usage_plan_key" "main" {
  key_id        = aws_api_gateway_api_key.digitechkey.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.digitecchusageplan.id
}