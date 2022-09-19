
data "template_file" "fmgr_userdata_byol" {
  template = file("./config_templates/fmgr-userdata-byol.tpl")

  vars = {
    fmgr_byol_license      = file("${path.module}/${var.fmgr_byol_license}")
    fmgr_admin_password     = var.fmgr_admin_password
  }
}

data "template_file" "fmgr_userdata_paygo" {
  template = file("./config_templates/fmgr-userdata-paygo.tpl")

  vars = {
    fmgr_admin_password     = var.fmgr_admin_password
  }
}

data "aws_ami" "fortimanager_byol" {
  most_recent = true

  filter {
    name                         = "name"
    values                       = ["FortiManager VM64-AWS *(${var.fortimanager_os_version})*"]
  }

  filter {
    name                         = "virtualization-type"
    values                       = ["hvm"]
  }

  owners                         = ["679593333241"] # Canonical
}

module "iam_profile" {
  source = "git::https://github.com/40netse/terraform-modules.git//aws_ec2_instance_iam_role"

  aws_region                  = var.aws_region
  customer_prefix             = var.cp
  environment                 = var.env
}

#
# This is an "allow all" security group, but a place holder for a more strict SG
#
resource aws_security_group "fortimanager_sg" {
  name = "allow_public_subnets"
  description = "${var.name} Allow all traffic from public Subnets"
  vpc_id = var.vpc_id
  ingress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "allow_public_subnets"
  }
}

module "fortimanager" {
  source                      = "git::https://github.com/40netse/terraform-modules.git//aws_ec2_instance"
  aws_ec2_instance_name       = "${var.cp}-${var.env}-${var.fortimanager_instance_name}"
  availability_zone           = var.availability_zone
  instance_type               = var.fortimanager_instance_type
  public_subnet_id            = var.subnet_id
  public_ip_address           = var.ip_address
  aws_ami                     = data.aws_ami.fortimanager_byol.id
  enable_public_ips           = var.enable_public_ips
  keypair                     = var.keypair
  security_group_public_id    = aws_security_group.fortimanager_sg.id
  iam_instance_profile_id     = module.iam_profile.id
  userdata_rendered           = var.use_fortimanager_byol ? data.template_file.fmgr_userdata_byol.rendered : data.template_file.fmgr_userdata_paygo.rendered
}

