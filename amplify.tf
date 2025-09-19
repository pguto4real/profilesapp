


resource "aws_amplify_app" "react_app" {
 name        = var.app_name
  repository  = var.github_repo
  oauth_token = var.github_token

build_spec = <<EOT
version: 1
frontend:
  phases:
    preBuild:
      commands:
        - npm install
    build:
      commands:
        - npm run build
  artifacts:
    baseDirectory: dist
    files:
      - '**/*'
  cache:
    paths:
      - node_modules/**/*
EOT
}
resource "aws_amplify_branch" "main" {
  app_id      = aws_amplify_app.react_app.id
  branch_name = "main" # The branch you want Amplify to auto-deploy
}