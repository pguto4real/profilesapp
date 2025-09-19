

# Amplify App
resource "aws_amplify_app" "react_app" {
  name       = "my-react-app"
  repository = "https://github.com/pguto4real/profilesapp.git"
 oauth_token = var.github_token
 
  # Build spec for React app
  build_spec = <<EOT
version: 1
backend:
  phases:
    build:
      commands:
        - npm ci --cache .npm --prefer-offline
        - npx ampx pipeline-deploy --branch $AWS_BRANCH --app-id $AWS_APP_ID
frontend:
  phases:
    build:
      commands:
        - npm run build
  artifacts:
    baseDirectory: dist
    files:
      - '**/*'
  cache:
    paths:
      - .npm/**/*
EOT
}



# Branch (main) with auto build enabled
resource "aws_amplify_branch" "main" {
  app_id            = aws_amplify_app.react_app.id
  branch_name       = "main"       # must match your GitHub branch name
  enable_auto_build = true         # 👈 ensures auto deploy
  framework         = "React"      # helps Amplify detect framework
}
