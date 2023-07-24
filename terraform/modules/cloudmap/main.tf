resource "aws_service_discovery_private_dns_namespace" "cloudacademy" {
  name        = "cloudacademy.terraform.local"
  description = "cloudacademy"
  vpc         = var.vpc_id
}

resource "aws_service_discovery_service" "cloudacademy" {
  name = "db"

  dns_config {
    namespace_id = aws_service_discovery_private_dns_namespace.cloudacademy.id

    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }

  #   health_check_custom_config {
  #     failure_threshold = 1
  #   }
}
