resource "aws_key_pair" "titus_deployer" {
  key_name   = "titus_deployer"
  public_key = "${file("${var.public_key}")}"
}

resource "aws_instance" "bastion" {
  ami                         = "${data.aws_ami.ubuntu_xenial.id}"
  instance_type               = "t2.nano"
  key_name                    = "${aws_key_pair.titus_deployer.key_name}"
  vpc_security_group_ids      = ["${aws_security_group.titusbastion.id}"]
  subnet_id                   = "${aws_subnet.public_subnet_1.id}"
  associate_public_ip_address = "true"
}

resource "aws_instance" "prereqs" {
  ami                    = "${data.aws_ami.ubuntu_xenial.id}"
  instance_type          = "t2.large"
  user_data              = "${file("scripts/cloud-init-prereqs.sh")}"
  key_name               = "${aws_key_pair.titus_deployer.key_name}"
  vpc_security_group_ids = ["${aws_security_group.titusmaster-mainvpc.id}"]
  subnet_id              = "${aws_subnet.private_subnet_1.id}"
}

resource "aws_iam_instance_profile" "titusmasterInstanceProfile" {
  name = "titusmasterInstanceProfile"
  role = "${aws_iam_role.titusmasterInstanceProfile.name}"
}

resource "aws_instance" "master" {
  ami                    = "${data.aws_ami.ubuntu_xenial.id}"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.titus_deployer.key_name}"
  user_data              = "${file("scripts/cloud-init-master.sh")}"
  vpc_security_group_ids = ["${aws_security_group.titusmaster-mainvpc.id}"]
  subnet_id              = "${aws_subnet.private_subnet_1.id}"
  iam_instance_profile   = "${aws_iam_instance_profile.titusmasterInstanceProfile.id}"
}

resource "aws_instance" "gateway" {
  ami                    = "${data.aws_ami.ubuntu_xenial.id}"
  instance_type          = "t2.micro"
  key_name               = "${aws_key_pair.titus_deployer.key_name}"
  user_data              = "${file("scripts/cloud-init-gateway.sh")}"
  vpc_security_group_ids = ["${aws_security_group.titusmaster-mainvpc.id}"]
  subnet_id              = "${aws_subnet.private_subnet_1.id}"
  iam_instance_profile   = "${aws_iam_instance_profile.titusmasterInstanceProfile.id}"
}

resource "aws_launch_configuration" "titusagent" {
  name                 = "titusagent"
  image_id             = "${data.aws_ami.ubuntu_xenial.id}"
  instance_type        = "t2.large"
  security_groups      = ["${aws_security_group.titusmaster-mainvpc.id}"]
  key_name             = "${aws_key_pair.titus_deployer.key_name}"
  user_data            = "${file("scripts/cloud-init-agent.yml")}"
  iam_instance_profile = "${aws_iam_instance_profile.titusmasterInstanceProfile.id}"

  root_block_device = [
    {
      volume_size = "30"
      volume_type = "gp2"
    },
  ]
}

resource "aws_autoscaling_group" "titusagent" {
  name                      = "titusagent"
  max_size                  = 1
  min_size                  = 1
  desired_capacity          = 1
  health_check_grace_period = 60
  health_check_type         = "EC2"
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.titusagent.name}"
  vpc_zone_identifier       = ["${aws_subnet.private_subnet_1.id}"]
}