# ########################
# # DYNAMO DB TABLE TASK
# ########################



# resource "aws_dynamodb_table" "tasks" {
#   name         = "Tasks"
#   billing_mode = "PAY_PER_REQUEST" # On-demand billing (no capacity planning required)
#   hash_key     = "taskId"

#   attribute {
#     name = "taskId"
#     type = "S" # String type
#   }

#   tags = {
#     Environment = "dev"
#     Project     = "TaskTracker"
#   }
# }


# ########################
# # IAM Role for Lambda with DynamoDB + CloudWatch permissions
# ########################

# resource "aws_iam_role" "lambda_exec_role" {
#   name = "lambda_exec_role"

#   assume_role_policy = jsonencode({
#     Version = "2012-10-17",
#     Statement = [
#       {
#         Effect = "Allow",
#         Principal = {
#           Service = "lambda.amazonaws.com"
#         },
#         Action = "sts:AssumeRole"
#       }
#     ]
#   })

#   tags = {
#     Name = "lambda_exec_role"
#   }
# }

# # Attach managed policies (logs + DynamoDB access)
# resource "aws_iam_role_policy_attachment" "lambda_logs" {
#   role       = aws_iam_role.lambda_exec_role.name
#   policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
# }

# resource "aws_iam_role_policy_attachment" "lambda_dynamodb" {
#   role       = aws_iam_role.lambda_exec_role.name
#   policy_arn = "arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess"
# }

# ########################
# # LAMBDA
# ########################

# # Helper to reduce repetition
# locals {
#   lambda_functions = {
#     createTask = <<EOF
# import boto3, json, uuid
# dynamodb = boto3.resource('dynamodb')
# table = dynamodb.Table('Tasks')
# def lambda_handler(event, context):
#     body = json.loads(event['body'])
#     task_id = str(uuid.uuid4())
#     table.put_item(Item={"taskId": task_id, "task": body["task"], "done": False})
#     return {"statusCode":200,"body":json.dumps({"taskId": task_id})}
# EOF

#     listTasks = <<EOF
# import boto3, json
# dynamodb = boto3.resource('dynamodb')
# table = dynamodb.Table('Tasks')
# def lambda_handler(event, context):
#     response = table.scan()
#     return {"statusCode":200,"body":json.dumps(response['Items'])}
# EOF

#     markTaskDone = <<EOF
# import boto3, json
# dynamodb = boto3.resource('dynamodb')
# table = dynamodb.Table('Tasks')
# def lambda_handler(event, context):
#     body = json.loads(event['body'])
#     task_id = body["taskId"]
#     table.update_item(Key={"taskId": task_id}, UpdateExpression="set done = :d",
#                       ExpressionAttributeValues={":d": True}, ReturnValues="UPDATED_NEW")
#     return {"statusCode":200,"body":json.dumps({"message": "Task marked done"})}
# EOF

#     deleteTask = <<EOF
# import boto3, json
# dynamodb = boto3.resource('dynamodb')
# table = dynamodb.Table('Tasks')
# def lambda_handler(event, context):
#     body = json.loads(event['body'])
#     task_id = body["taskId"]
#     table.delete_item(Key={"taskId": task_id})
#     return {"statusCode":200,"body":json.dumps({"message": "Task deleted"})}
# EOF
#   }
# }

# # Create all Lambda functions
# resource "aws_lambda_function" "crud_functions" {
#   for_each      = local.lambda_functions
#   function_name = each.key
#   role          = aws_iam_role.lambda_exec_role.arn
#   handler       = "${each.key}.lambda_handler"
#   runtime       = "python3.11"

# #   filename         = "${path.module}/${each.key}.zip"
# #   source_code_hash = filebase64sha256("${path.module}/${each.key}.zip")

# #   depends_on = [null_resource.zip_sources]

#   filename         = archive_file.lambda_packages[each.key].output_path
#   source_code_hash = archive_file.lambda_packages[each.key].output_base64sha256
# }

# # Package each function into zip
# resource "local_file" "lambda_sources" {
#   for_each = local.lambda_functions
#   content  = each.value
#   filename = "${path.module}/${each.key}.py"
# }

# resource "archive_file" "lambda_packages" {
#   for_each    = local.lambda_functions
#   type        = "zip"
#   source_file = local_file.lambda_sources[each.key].filename
#   output_path = "${path.module}/${each.key}.zip"
# }

# # resource "null_resource" "zip_sources" {
# #   for_each = local.lambda_functions
# #   provisioner "local-exec" {
# #     command = "zip -j ${path.module}/${each.key}.zip ${path.module}/${each.key}.py"
# #   }
# #   triggers = {
# #     source = local.lambda_functions[each.key]
# #   }
# # }


# # -----------------------
# # API Gateway REST API
# # -----------------------
# resource "aws_api_gateway_rest_api" "task_api" {
#   name        = "TaskAPI"
#   description = "API Gateway for Task management"
# }

# # Root resource (/tasks)
# resource "aws_api_gateway_resource" "tasks" {
#   rest_api_id = aws_api_gateway_rest_api.task_api.id
#   parent_id   = aws_api_gateway_rest_api.task_api.root_resource_id
#   path_part   = "tasks"
# }

# # Child resource (/tasks/{id})
# resource "aws_api_gateway_resource" "task_id" {
#   rest_api_id = aws_api_gateway_rest_api.task_api.id
#   parent_id   = aws_api_gateway_resource.tasks.id
#   path_part   = "{id}"
# }

# # -----------------------
# # Methods + Integrations
# # -----------------------

# # POST /tasks -> createTask Lambda
# resource "aws_api_gateway_method" "post_tasks" {
#   rest_api_id   = aws_api_gateway_rest_api.task_api.id
#   resource_id   = aws_api_gateway_resource.tasks.id
#   http_method   = "POST"
#   authorization = "COGNITO_USER_POOLS"
#   authorizer_id = aws_api_gateway_authorizer.cognito_auth.id
# }

# resource "aws_api_gateway_integration" "post_tasks_lambda" {
#   rest_api_id             = aws_api_gateway_rest_api.task_api.id
#   resource_id             = aws_api_gateway_resource.tasks.id
#   http_method             = aws_api_gateway_method.post_tasks.http_method
#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = aws_lambda_function.crud_functions["createTask"].invoke_arn
# }

# # GET /tasks -> listTasks Lambda
# resource "aws_api_gateway_method" "get_tasks" {
#   rest_api_id   = aws_api_gateway_rest_api.task_api.id
#   resource_id   = aws_api_gateway_resource.tasks.id
#   http_method   = "GET"
#   authorization = "COGNITO_USER_POOLS"
#   authorizer_id = aws_api_gateway_authorizer.cognito_auth.id
# }

# resource "aws_api_gateway_integration" "get_tasks_lambda" {
#   rest_api_id             = aws_api_gateway_rest_api.task_api.id
#   resource_id             = aws_api_gateway_resource.tasks.id
#   http_method             = aws_api_gateway_method.get_tasks.http_method
#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = aws_lambda_function.crud_functions["listTasks"].invoke_arn
# }

# # PUT /tasks/{id} -> markTaskDone Lambda
# resource "aws_api_gateway_method" "put_task" {
#   rest_api_id   = aws_api_gateway_rest_api.task_api.id
#   resource_id   = aws_api_gateway_resource.task_id.id
#   http_method   = "PUT"
#   authorization = "COGNITO_USER_POOLS"
#   authorizer_id = aws_api_gateway_authorizer.cognito_auth.id
# }

# resource "aws_api_gateway_integration" "put_task_lambda" {
#   rest_api_id             = aws_api_gateway_rest_api.task_api.id
#   resource_id             = aws_api_gateway_resource.task_id.id
#   http_method             = aws_api_gateway_method.put_task.http_method
#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = aws_lambda_function.crud_functions["markTaskDone"].invoke_arn
# }

# # DELETE /tasks/{id} -> deleteTask Lambda
# resource "aws_api_gateway_method" "delete_task" {
#   rest_api_id   = aws_api_gateway_rest_api.task_api.id
#   resource_id   = aws_api_gateway_resource.task_id.id
#   http_method   = "DELETE"
#   authorization = "COGNITO_USER_POOLS"
#   authorizer_id = aws_api_gateway_authorizer.cognito_auth.id
# }

# resource "aws_api_gateway_integration" "delete_task_lambda" {
#   rest_api_id             = aws_api_gateway_rest_api.task_api.id
#   resource_id             = aws_api_gateway_resource.task_id.id
#   http_method             = aws_api_gateway_method.delete_task.http_method
#   integration_http_method = "POST"
#   type                    = "AWS_PROXY"
#   uri                     = aws_lambda_function.crud_functions["deleteTask"].invoke_arn
# }

# # -----------------------
# # Lambda Permissions for API Gateway
# # -----------------------
# resource "aws_lambda_permission" "apigw_create_task" {
#   statement_id  = "AllowAPIGatewayInvokeCreateTask"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.crud_functions["createTask"].function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_api_gateway_rest_api.task_api.execution_arn}/*/*"
# }

# resource "aws_lambda_permission" "apigw_list_tasks" {
#   statement_id  = "AllowAPIGatewayInvokeListTasks"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.crud_functions["listTasks"].function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_api_gateway_rest_api.task_api.execution_arn}/*/*"
# }

# resource "aws_lambda_permission" "apigw_mark_task_done" {
#   statement_id  = "AllowAPIGatewayInvokeMarkTaskDone"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.crud_functions["markTaskDone"].function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_api_gateway_rest_api.task_api.execution_arn}/*/*"
# }

# resource "aws_lambda_permission" "apigw_delete_task" {
#   statement_id  = "AllowAPIGatewayInvokeDeleteTask"
#   action        = "lambda:InvokeFunction"
#   function_name = aws_lambda_function.crud_functions["deleteTask"].function_name
#   principal     = "apigateway.amazonaws.com"
#   source_arn    = "${aws_api_gateway_rest_api.task_api.execution_arn}/*/*"
# }

# # -----------------------
# # Deployment & Stage
# # -----------------------
# resource "aws_api_gateway_deployment" "task_api_deployment" {
#   depends_on = [
#     aws_api_gateway_integration.post_tasks_lambda,
#     aws_api_gateway_integration.get_tasks_lambda,
#     aws_api_gateway_integration.put_task_lambda,
#     aws_api_gateway_integration.delete_task_lambda
#   ]

#   rest_api_id = aws_api_gateway_rest_api.task_api.id
# }

# # Stage (attaches a stage name like "dev" to the deployment)
# resource "aws_api_gateway_stage" "dev" {
#   rest_api_id   = aws_api_gateway_rest_api.task_api.id
#   deployment_id = aws_api_gateway_deployment.task_api_deployment.id
#   stage_name    = "dev"
# }




# # ------------------------
# # Cognito User Pool (from Part 4)
# # ------------------------
# resource "aws_cognito_user_pool" "task_users" {
#   name = "TaskUsers"

#   username_attributes      = ["email"]
#   auto_verified_attributes = ["email"]

#   admin_create_user_config {
#     allow_admin_create_user_only = false
#   }
# }

# resource "aws_cognito_user_pool_client" "task_app_client" {
#   name         = "taskApp"
#   user_pool_id = aws_cognito_user_pool.task_users.id

#   generate_secret               = false
#   explicit_auth_flows           = ["ALLOW_USER_PASSWORD_AUTH", "ALLOW_REFRESH_TOKEN_AUTH", "ALLOW_USER_SRP_AUTH"]
#   prevent_user_existence_errors = "ENABLED"
# }

# # ------------------------
# # API Gateway Authorizer
# # ------------------------
# resource "aws_api_gateway_authorizer" "cognito_auth" {
#   name            = "TaskCognitoAuthorizer"
#   rest_api_id     = aws_api_gateway_rest_api.task_api.id
#   identity_source = "method.request.header.Authorization"
#   type            = "COGNITO_USER_POOLS"
#   provider_arns   = [aws_cognito_user_pool.task_users.arn]
# }
