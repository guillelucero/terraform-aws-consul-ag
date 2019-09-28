data "template_file" "server-lc" {
  template = "${file("${path.module}/templates/consul.sh.tpl")}"

  vars = {
    consul_version = "0.7.5"

    config = <<EOF
     "bootstrap_expect": 2,
     "node_name": "${var.namespace}-server-RANDOM",
     "retry_join_ec2": {
       "tag_key": "${var.consul_join_tag_key}",
       "tag_value": "${var.consul_join_tag_value}"
     },
     "server": true
    EOF
  }
}



# Create the user-data for the Consul client LUNCH CONFIGURATION
data "template_file" "client-lc" {
  template = "${file("${path.module}/templates/consul.sh.tpl")}"

  vars = {
    consul_version = "0.7.5"

    config = <<EOF
     "node_name": "${var.namespace}-client-RANDOM",
     "retry_join_ec2": {
       "tag_key": "${var.consul_join_tag_key}",
       "tag_value": "${var.consul_join_tag_value}"
     },
     "server": false
    EOF
  }
}


# Lunch Configuration Servers
resource "aws_launch_configuration" "consul_server" {
  name_prefix   = "${var.namespace}-lc-server-"
  image_id      = "${data.aws_ami.ubuntu-1404.id}"
  instance_type = "${var.instance_type}"
  key_name      = "${aws_key_pair.consul.id}"
  iam_instance_profile   = "${aws_iam_instance_profile.consul-join.name}"
  user_data = "${data.template_file.server-lc.rendered}"
  security_groups = ["${aws_security_group.consul.id}"] 


  lifecycle {
    create_before_destroy = true
  }
}

# AutoScaling Group Servers
resource "aws_autoscaling_group" "consul_server" {
  name                 = "${var.namespace}-asg-servers"
  launch_configuration = "${aws_launch_configuration.consul_server.name}"
  min_size             = 1
  max_size             = 4
  desired_capacity     = 2
  availability_zones = "${data.aws_availability_zones.available.names}" 
  vpc_zone_identifier = ["${element(aws_subnet.consul.*.id, 0)}","${element(aws_subnet.consul.*.id, 1)}"]

  lifecycle {
    create_before_destroy = true
  }


  tags = [
      {
        key                 = "Name"
        value               = "${var.namespace}-serve"
        #value               = "${var.namespace}-server-${random_string.random.result}"
        propagate_at_launch = true
      },
      {
        key                 = "${var.consul_join_tag_key}"
        value               = "${var.consul_join_tag_value}"
        propagate_at_launch = true
      },
    ]


}




# Lunch Configuration Client
resource "aws_launch_configuration" "consul_client" {
  name_prefix   = "${var.namespace}-lc-client-"
  image_id      = "${data.aws_ami.ubuntu-1404.id}"
  instance_type = "${var.instance_type}"
  key_name      = "${aws_key_pair.consul.id}"
  iam_instance_profile   = "${aws_iam_instance_profile.consul-join.name}"
  user_data = "${data.template_file.client-lc.rendered}"
  security_groups = ["${aws_security_group.consul.id}"]


  lifecycle {
    create_before_destroy = true
  }
}

# AutoScaling Group Client
resource "aws_autoscaling_group" "consul_client" {
  name                 = "${var.namespace}-asg-client"
  launch_configuration = "${aws_launch_configuration.consul_client.name}"
  min_size             = 1
  max_size             = 4
  desired_capacity     = 1
  availability_zones = "${data.aws_availability_zones.available.names}"
  vpc_zone_identifier = ["${element(aws_subnet.consul.*.id, 0)}","${element(aws_subnet.consul.*.id, 1)}"]

  lifecycle {
    create_before_destroy = true
  }


  tags = [
      {
        key                 = "Name"
        value               = "${var.namespace}-client"
        propagate_at_launch = true
      },
      {
        key                 = "${var.consul_join_tag_key}"
        value               = "${var.consul_join_tag_value}"
        propagate_at_launch = true
      },
    ]


}


