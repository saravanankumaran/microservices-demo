terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "ap-south-1"
}

variable "account_id" {
  description = "AWS Account ID where the role will live."
  type        = string
}

variable "user_name" {
  description = "Existing IAM user to be added to group (or created if you enable the resource below)."
  type        = string
}

# ---------------------------
# IAM Role for eksctl admin
# ---------------------------
resource "aws_iam_role" "eks_admin_role" {
  name = "EKSAdminRole"

  # Option A: trust whole account (broad, but OK for personal account)
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          AWS = "arn:aws:iam::${var.account_id}:root"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach inline eksctl-admin policy
resource "aws_iam_role_policy" "eks_admin_inline_policy" {
  name   = "eksctl-admin-policy"
  role   = aws_iam_role.eks_admin_role.id
  policy = file("${path.module}/eksctl-admin-policy.json")
}

# ---------------------------
# IAM Group for admins
# ---------------------------
resource "aws_iam_group" "eks_admin_group" {
  name = "EKSAdminGroup"
}

resource "aws_iam_group_policy" "eks_admin_group_policy" {
  group = aws_iam_group.eks_admin_group.name
  name  = "AssumeEksAdminRole"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect   = "Allow",
        Action   = ["sts:AssumeRole", "sts:TagSession"],
        Resource = aws_iam_role.eks_admin_role.arn
      }
    ]
  })
}


# -------------------------------
# Assign IAM USER to the group
# -------------------------------
resource "aws_iam_user_group_membership" "eks_admin_user_group_membership" {
  user = var.user_name
  groups = [aws_iam_group.eks_admin_group.name]
}
