resource "aws_key_pair" "webapp_key" {
  key_name   = "webapp-key"
  public_key = file(pathexpand("~/.ssh/webapp-key.pub"))
}