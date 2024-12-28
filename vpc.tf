locals {
  # TODO: simplify or reorganize?
  public_subnet_cidrs = [for s in range(0, 3) : cidrsubnet(aws_vpc.default.cidr_block, 8, s)]
}


resource "aws_vpc" "default" {
  cidr_block = "10.0.0.0/16"

  enable_dns_hostnames = true
}

resource "aws_internet_gateway" "default" {
  vpc_id = aws_vpc.default.id
}

resource "aws_subnet" "public" {
  vpc_id = aws_vpc.default.id

  for_each = zipmap(var.availability_zones, local.public_subnet_cidrs)

  availability_zone = each.key

  cidr_block              = each.value
  map_public_ip_on_launch = true

  tags = {
    Name = "${aws_vpc.default.cidr_block}-public"
    #     "kubernetes.io/cluster/${local.name}" = "shared"
  }
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.default.id

  tags = {
    Name = "${aws_vpc.default.cidr_block}-public"
  }
}

resource "aws_route" "public" {
  route_table_id = aws_route_table.public.id

  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.default.id
}



resource "aws_route_table_association" "public" {
  for_each = aws_subnet.public

  route_table_id = aws_route_table.public.id
  subnet_id      = each.value.id
}