resource "aws_instance" "blue" {
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id = var.public_subnet_id

  vpc_security_group_ids = [
    var.web_security_group_id
  ]

  associate_public_ip_address = true

  iam_instance_profile = var.iam_instance_profile_name

  tags = {
    Name        = "${var.name_prefix}-blue-server"
    Environment = "blue"
  }
}


resource "aws_instance" "green" {
  ami           = var.ami_id
  instance_type = var.instance_type

  subnet_id = var.public_subnet_2_id

  vpc_security_group_ids = [
    var.web_security_group_id
  ]

  associate_public_ip_address = true

  iam_instance_profile = var.iam_instance_profile_name

  tags = {
    Name        = "${var.name_prefix}-green-server"
    Environment = "green"
  }
}