output "vpc_id" {
  value = aws_vpc.vpc.id
}

output "private_subnets" {
  value = [for subnet in aws_subnet.private_subnet : subnet.id]
}

output "public_subnets" {
  value = [for subnet in aws_subnet.public_subnet : subnet.id]
}

output "private_subnets_cidr_blocks" {
  value = [for subnet in aws_subnet.private_subnet : subnet.cidr_block]
}

output "public_subnets_cidr_blocks" {
  value = [for subnet in aws_subnet.public_subnet : subnet.cidr_block]
}
