aws_ami    = "ami-06d146e85d1709abb"
aws_region = "ap-south-1"

aws_iam_instance_profile_role = "EC2StorageAccess"

ec2_nodes_config = {
  "master-1" : {
    az               = "ap-south-1a"
    role             = "primary-master"
    instance_type    = "c6a.large"
    root_volume_size = 50
    with_elastic_ip  = false
  },

  "master-2" : {
    az               = "ap-south-1b"
    role             = "secondary-master"
    instance_type    = "c6a.large"
    root_volume_size = 50
    with_elastic_ip  = false
  },

  "master-3" : {
    az               = "ap-south-1c"
    role             = "secondary-master"
    instance_type    = "c6a.large"
    root_volume_size = 50
    with_elastic_ip  = false
  },
}

spot_settings = {
  enabled                      = true
  spot_fleet_tagging_role_name = "aws-ec2-spot-fleet-tagging-role"
}

spot_nodes_config = {
  "spot-1" : {
    az   = "ap-south-1b"
    vcpu = {
      min = 1
      max = 2
    }

    memory_per_vcpu = {
      min = 1.5
      max = 2
    }
  },
  "spot-2" : {
    az   = "ap-south-1c"
    vcpu = {
      min = 1
      max = 2
    }

    memory_per_vcpu = {
      min = 1.5
      max = 2
    }
  },
}

disable_ssh = false

k3s_backup_to_s3 = {
  enabled       = true
  bucket_name   = "kloudlite-dev-tf"
  bucket_region = "ap-south-1"
  bucket_folder = "kloudlite/cluster-dev/etcd-snapshots/"
}

restore_from_latest_s3_snapshot = false
kloudlite_release               = "v1.0.5-nightly"
