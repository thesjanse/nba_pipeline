terraform {
  required_providers {
    yandex = {
      source = "yandex-cloud/yandex"
    }
  }
  required_version = ">= 1.0"
}

provider "yandex" {
  cloud_id  = var.cloud_id
  folder_id = var.folder_id
  zone      = var.zone
}

# create object storage service account
resource "yandex_iam_service_account" "storage-sa" {
  name        = "storage-sa"
  description = "Service account for object storage management."
  folder_id   = var.folder_id
}

# provide role for object storage service account
resource "yandex_resourcemanager_folder_iam_binding" "storage-uploader-iam" {
  folder_id = var.folder_id
  role      = "storage.admin"

  members = [
    "serviceAccount:${yandex_iam_service_account.storage-sa.id}"
  ]
}

# create static access key
resource "yandex_iam_service_account_static_access_key" "sa-static-key" {
  service_account_id = yandex_iam_service_account.storage-sa.id
  description        = "Static Access Key for object storage."
}

# create dataproc sevice account
resource "yandex_iam_service_account" "dataproc-sa" {
  name        = "dataproc-sa"
  description = "Service account for dataproc cluster."
  folder_id   = var.folder_id
}

# provide roles for dataproc service account
resource "yandex_resourcemanager_folder_iam_binding" "dataproc-agent-iam" {
  folder_id = var.folder_id
  role      = "dataproc.agent"

  members = [
    "serviceAccount:${yandex_iam_service_account.dataproc-sa.id}"
  ]
}

resource "yandex_resourcemanager_folder_iam_binding" "dataproc-storage-iam" {
  folder_id = var.folder_id
  role      = "storage.editor"

  members = [
    "serviceAccount:${yandex_iam_service_account.dataproc-sa.id}"
  ]
}

# initialize data lake bucket
resource "yandex_storage_bucket" "data-lake" {
  bucket        = "nba-${var.folder_id}"
  force_destroy = true
  access_key    = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key    = yandex_iam_service_account_static_access_key.sa-static-key.secret_key

  grant {
    id          = yandex_iam_service_account.dataproc-sa.id
    type        = "CanonicalUser"
    permissions = ["READ"]
  }
}

# initialize dataproc bucket
resource "yandex_storage_bucket" "dataproc-bucket" {
  bucket        = "dataproc-bucket-${var.folder_id}"
  force_destroy = true
  access_key    = yandex_iam_service_account_static_access_key.sa-static-key.access_key
  secret_key    = yandex_iam_service_account_static_access_key.sa-static-key.secret_key

  grant {
    id          = yandex_iam_service_account.dataproc-sa.id
    type        = "CanonicalUser"
    permissions = ["READ", "WRITE"]
  }
}

# initialize network
resource "yandex_vpc_network" "main-network" {
  name = "main-network"
}

# initialize subnetwork
resource "yandex_vpc_subnet" "clickhouse-subnet" {
  name           = "clickhouse-subnet"
  zone           = var.zone
  network_id     = yandex_vpc_network.main-network.id
  v4_cidr_blocks = ["10.1.0.0/24"]
}

# get external ip
resource "yandex_vpc_address" "ext_clickhouse_address" {
  name = "clickhouse_address"

  external_ipv4_address {
    zone_id = var.zone
  }
}

#initialize clickhouse
resource "yandex_mdb_clickhouse_cluster" "clickhouse" {
  name                = "clickhouse"
  network_id          = yandex_vpc_network.main-network.id
  environment         = "PRODUCTION"
  deletion_protection = false


  clickhouse {
    resources {
      resource_preset_id = "b1.micro"
      disk_type_id       = "network-hdd"
      disk_size          = 12
    }

    config {
      log_level                       = "TRACE"
      max_connections                 = 20
      max_concurrent_queries          = 100
      keep_alive_timeout              = 5
      uncompressed_cache_size         = 2000000000
      mark_cache_size                 = 2000000000
      max_partition_size_to_drop      = 0
      max_table_size_to_drop          = 0
      timezone                        = "UTC"
      geobase_uri                     = ""
      metric_log_enabled              = true
      metric_log_retention_size       = 222870912
      metric_log_retention_time       = 3600000
      part_log_retention_size         = 222870912
      part_log_retention_time         = 3600000
      query_log_retention_size        = 222870912
      query_log_retention_time        = 3600000
      query_thread_log_enabled        = true
      query_thread_log_retention_size = 222870912
      query_thread_log_retention_time = 3600000
      text_log_enabled                = true
      text_log_retention_size         = 222870912
      text_log_retention_time         = 3600000
      text_log_level                  = "TRACE"

      merge_tree {
        replicated_deduplication_window                           = 100
        replicated_deduplication_window_seconds                   = 604800
        parts_to_delay_insert                                     = 150
        parts_to_throw_insert                                     = 300
        max_replicated_merges_in_queue                            = 16
        number_of_free_entries_in_pool_to_lower_max_size_of_merge = 8
        max_bytes_to_merge_at_min_space_in_pool                   = 1048576
      }

      kafka {
        security_protocol = "SECURITY_PROTOCOL_PLAINTEXT"
        sasl_mechanism    = "SASL_MECHANISM_GSSAPI"
        sasl_username     = var.sasl_username
        sasl_password     = var.sasl_password
      }

      rabbitmq {
        username = var.rabbit_user
        password = var.rabbit_password
      }

      compression {
        method              = "LZ4"
        min_part_size       = 1024
        min_part_size_ratio = 0.5
      }

      compression {
        method              = "ZSTD"
        min_part_size       = 2048
        min_part_size_ratio = 0.7
      }

      graphite_rollup {
        name = "rollup1"
        pattern {
          regexp   = "abc"
          function = "func1"
          retention {
            age       = 1000
            precision = 3
          }
        }
      }

      graphite_rollup {
        name = "rollup2"
        pattern {
          function = "func2"
          retention {
            age       = 2000
            precision = 5
          }
        }
      }

    }
  }

  database {
    name = var.clickhouse_db_name
  }

  user {
    name     = var.clickhouse_username
    password = var.clickhouse_password
    permission {
      database_name = var.clickhouse_db_name
    }
  }

  host {
    type      = "CLICKHOUSE"
    zone      = var.zone
    subnet_id = yandex_vpc_subnet.clickhouse-subnet.id
  }

  maintenance_window {
    type = "WEEKLY"
    day  = "SUN"
    hour = 12
  }

  access {
    data_lens  = true
    metrika    = false
    serverless = false
    web_sql    = true
  }
}