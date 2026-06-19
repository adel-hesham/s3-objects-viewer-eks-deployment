# Get the current AWS region


# Get the VPC route table IDs — endpoint needs to know which route tables to update
# We attach it to both public and private route tables so all subnets can use it

resource "aws_vpc_endpoint" "s3" {
  vpc_id            = aws_vpc.main.id
  service_name      = "com.amazonaws.${data.aws_region.current.region}.s3"
  vpc_endpoint_type = "Gateway"

  # attach to all route tables so both nodes and pods can reach S3 privately
  route_table_ids = concat(
    [aws_route_table.public.id],
    aws_route_table.private[*].id
  )

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect    = "Allow"
        Principal = "*"
        Action    = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "s3:DeleteObject",
          "s3:ListAllMyBuckets",    # list all buckets in the account,          # list objects inside a specific bucket
          "s3:GetBucketLocation"
        ]
        Resource  = "*"
      }
    ]
  })

  tags = merge(local.common_tags, {
    Name = "${var.cluster_name}-s3-endpoint"
  })
}