
resource "aws_dynamodb_table" "links" {
  name         = "${var.project_name}-links"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "short_code"

  attribute {
    name = "short_code"
    type = "S"
  }
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.project_name}-lambda-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_dynamodb" {
  name = "${var.project_name}-lambda-dynamodb-policy"
  role = aws_iam_role.lambda_exec.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:UpdateItem"
      ]
      Resource = aws_dynamodb_table.links.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_logs" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}
data "archive_file" "create_link_zip" {
  type        = "zip"
  source_dir  = "${path.module}/../backend"
  output_path = "${path.module}/create_link.zip"
}

resource "aws_lambda_function" "create_link" {
  function_name    = "${var.project_name}-create-link"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "create_link.handler"
  runtime          = "nodejs18.x"
  filename         = data.archive_file.create_link_zip.output_path
  source_code_hash = data.archive_file.create_link_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.links.name
    }
  }
}

resource "aws_lambda_function" "redirect" {
  function_name    = "${var.project_name}-redirect"
  role             = aws_iam_role.lambda_exec.arn
  handler          = "redirect.handler"
  runtime          = "nodejs18.x"
  filename         = data.archive_file.create_link_zip.output_path
  source_code_hash = data.archive_file.create_link_zip.output_base64sha256

  environment {
    variables = {
      TABLE_NAME = aws_dynamodb_table.links.name
    }
  }
}
resource "aws_apigatewayv2_api" "shortify" {
  name          = "shortify-api"
  protocol_type = "HTTP"
}

resource "aws_apigatewayv2_stage" "default" {
  api_id      = aws_apigatewayv2_api.shortify.id
  name        = "$default"
  auto_deploy = true
}

resource "aws_apigatewayv2_integration" "create_link" {
  api_id             = aws_apigatewayv2_api.shortify.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.create_link.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_integration" "redirect" {
  api_id             = aws_apigatewayv2_api.shortify.id
  integration_type   = "AWS_PROXY"
  integration_uri    = aws_lambda_function.redirect.invoke_arn
  integration_method = "POST"
}

resource "aws_apigatewayv2_route" "create_link" {
  api_id    = aws_apigatewayv2_api.shortify.id
  route_key = "POST /links"
  target    = "integrations/${aws_apigatewayv2_integration.create_link.id}"
}

resource "aws_apigatewayv2_route" "redirect" {
  api_id    = aws_apigatewayv2_api.shortify.id
  route_key = "GET /{short_code}"
  target    = "integrations/${aws_apigatewayv2_integration.redirect.id}"
}

resource "aws_lambda_permission" "create_link" {
  statement_id  = "AllowAPIGatewayInvokeCreate"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.create_link.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.shortify.execution_arn}/*/*"
}

resource "aws_lambda_permission" "redirect" {
  statement_id  = "AllowAPIGatewayInvokeRedirect"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.redirect.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_apigatewayv2_api.shortify.execution_arn}/*/*"
}
