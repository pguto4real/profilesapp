

# Amplify App
resource "aws_amplify_app" "react_app" {
  name       = "my-react-app"
  repository = "https://github.com/pguto4real/profilesapp.git"
 oauth_token = var.github_token
  environment_variables = {
    ENV = "dev"
  }
   auto_branch_creation_config {
    enable_auto_build            = true
    enable_pull_request_preview  = true
    stage                        = "DEVELOPMENT"
  }
  # Build spec for React app
  build_spec = <<EOT
version: 1
frontend:
  phases:
    preBuild:
      commands:
        - npm ci
    build:
      commands:
        - npm run build
  artifacts:
    baseDirectory: build
    files:
      - '**/*'
  cache:
    paths:
      - node_modules/**/*
EOT
}



# Branch (main) with auto build enabled
resource "aws_amplify_branch" "main" {
  app_id            = aws_amplify_app.react_app.id
  branch_name       = "main"       # must match your GitHub branch name
  enable_auto_build = true         # 👈 ensures auto deploy
  framework         = "React"      # helps Amplify detect framework
}
