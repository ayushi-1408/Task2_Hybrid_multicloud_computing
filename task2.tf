provider "aws" {
  region = "ap-south-1"
  profile = "ayushi"
}


resource "aws_security_group" "tasksg11" {
 name = "tasksg11"
 description = "Allow port 80 and 22 inbound traffic"


 ingress {
 description = "SSH"
 from_port = 22
 to_port = 22
 protocol = "tcp"
 cidr_blocks = [ "0.0.0.0/0" ]
 }
 ingress {
 description = "HTTP"
 from_port = 80
 to_port = 80
 protocol = "tcp"
 cidr_blocks = [ "0.0.0.0/0" ]
 }
 egress {
 from_port = 0
 to_port = 0
 protocol = "-1"
 cidr_blocks = ["0.0.0.0/0"]
 }
 tags = {
 Name = "tasksg11"
 }
}

resource "aws_instance" "myins1" {
  ami           = "ami-0447a12f28fddb066"
  instance_type = "t2.micro"
  key_name = "key1"
  security_groups = [ aws_security_group.tasksg11.name]

  connection {
    type     = "ssh"
    user     = "ec2-user"
    private_key = file("C:/Users/user/Downloads/key1.pem")
    host     = aws_instance.myins1.public_ip
  }

  provisioner "remote-exec" {
    inline = [
      "sudo yum install httpd  php git -y",
      "sudo systemctl restart httpd",
      "sudo systemctl enable httpd",
    ]
  }

  tags = {
    Name = "myos1"
  }

}
resource "null_resource" "null1" {
 

  provisioner "local-exec" {
    command = "echo ${aws_instance.myins1.public_ip} > publicip.txt"
  }
}
output "my_public_ip"{
value= aws_instance.myins1.public_ip
}

resource "aws_efs_file_system" "allow_nfs" {
 depends_on =  [ aws_security_group.tasksg11,
                aws_instance.myins1,  ] 
  creation_token = "allow_nfs"


  tags = {
    Name = "allow_nfs"
  }
}
resource "aws_efs_mount_target" "alpha" {
 depends_on =  [ aws_efs_file_system.allow_nfs,
                         ] 
  file_system_id = aws_efs_file_system.allow_nfs.id
  subnet_id      = aws_instance.myins1.subnet_id
  security_groups = ["${aws_security_group.tasksg11.id}"]
}

resource "null_resource" "null-remote-1"  {
 depends_on = [ 
               aws_efs_mount_target.alpha,
                  ]
  connection {
    type     = "ssh"
    user     = "ec2-user"
    host     = aws_instance.myins1.public_ip
  }
  provisioner "remote-exec" {
      inline = [
        "sudo echo ${aws_efs_file_system.allow_nfs.dns_name}:/var/www/html efs defaults,_netdev 0 0 >> sudo /etc/fstab",
        "sudo mount  ${aws_efs_file_system.allow_nfs.dns_name}:/  /var/www/html",
        "sudo curl https://github.com/ayushi-1408/Task2_Hybrid_multicloud_computing.git/a.html > index.html",                                  "sudo cp index.html  /var/www/html/",
      ]
  }
}



resource "null_resource" "nullRemote" {
  depends_on = [
    
    aws_s3_bucket_object.at1234

  ]

  connection {
    type = "ssh"
    user = "ec2-user"
    host = aws_instance.myins1.public_ip
    private_key = file("C:/Users/user/Downloads/key1.pem")
    
  }
  provisioner "remote-exec" {
    inline = [
       "sudo mkfs.ext4 /dev/xvdb",
       "sudo mount /dev/xvdb /var/www/html",
       "sudo yum install git -y",
       "sudo rm -rf /var/www/html/*",
       "sudo git clone https://github.com/ayushi-1408/Task2_Hybrid_multicloud_computing.git   /temp_repo",
       "sudo cp -rf /temp_repo/* /var/www/html",
     
      
    ]
  }
}

resource "aws_s3_bucket" "at12" {
  bucket = "at12"
  acl    = "public-read"

  tags = {
    Name        = "at12"
    Environment = "Dev"
  }
}
locals {
  s3_origin_id = "mys312"
}

resource "aws_s3_bucket_object" "at1234" {
  depends_on = [ aws_s3_bucket.at12,
                null_resource.null-remote-1,
               
 ]
  bucket = "at12"
  key    = "aws.jpg"
  source = "C:/Users/user/Desktop/Saved Pictures/aws.jpg"
  acl  ="public-read"
  }

resource "aws_cloudfront_distribution" "s3cloudfront" {
enabled             = true
  is_ipv6_enabled     = true
  origin {
  
    domain_name = "${aws_s3_bucket.at12.bucket_regional_domain_name}"
    origin_id   = "${local.s3_origin_id}"

  }



  default_cache_behavior {
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "${local.s3_origin_id}"

    forwarded_values {
      query_string = false

      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "allow-all"

  }


  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  tags = {
    Environment = "production"
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
connection {
   type="ssh"
user ="ec2-user"
private_key=file("C:/Users/user/Downloads/key1.pem")
host=aws_instance.myins1.public_ip
  }

provisioner "remote-exec" {
    inline = [
      "sudo su << EOF",
                           "echo \"<img src='http://${self.domain_name}/${aws_s3_bucket_object.at1234.key} >\" >> /var/www/index.html",
			   
"EOF",
    ]
  }
}