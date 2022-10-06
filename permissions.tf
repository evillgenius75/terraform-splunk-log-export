# Copyright 2022 Google LLC
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     https://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

resource "google_pubsub_topic_iam_binding" "input_sub_publisher" {
  project = google_pubsub_topic.dataflow_input_pubsub_topic.project
  topic = google_pubsub_topic.dataflow_input_pubsub_topic.name
  role = "roles/pubsub.publisher"
  members = [
    google_logging_folder_sink.folder_log_sink.writer_identity,
    google_logging_organization_sink.organization_log_sink.writer_identity
  ]
}

resource "google_pubsub_subscription_iam_binding" "input_sub_subscriber" {
  project = google_pubsub_subscription.dataflow_input_pubsub_subscription.project
  subscription = google_pubsub_subscription.dataflow_input_pubsub_subscription.name
  role = "roles/pubsub.subscriber"
  members = [
    "serviceAccount:${local.dataflow_worker_service_account}"
  ]
}

resource "google_pubsub_subscription_iam_binding" "input_sub_viewer" {
  project = google_pubsub_subscription.dataflow_input_pubsub_subscription.project
  subscription = google_pubsub_subscription.dataflow_input_pubsub_subscription.name
  role = "roles/pubsub.viewer"
  members = [
    "serviceAccount:${local.dataflow_worker_service_account}"
  ]
}

resource "google_pubsub_topic_iam_binding" "deadletter_topic_publisher" {
  project = google_pubsub_topic.dataflow_deadletter_pubsub_topic.project
  topic = google_pubsub_topic.dataflow_deadletter_pubsub_topic.name
  role = "roles/pubsub.publisher"
  members = [
    "serviceAccount:${local.dataflow_worker_service_account}"
  ]
}

resource "google_storage_bucket_iam_binding" "dataflow_worker_bucket_access" {
  bucket = google_storage_bucket.dataflow_job_temp_bucket.name
  role = "roles/storage.objectAdmin"
  members = [
    "serviceAccount:${local.dataflow_worker_service_account}"
  ]
}

resource "google_project_iam_binding" "dataflow_worker_role" {
  project = var.project
  role = "roles/dataflow.worker"
  members = [
    "serviceAccount:${local.dataflow_worker_service_account}"
  ]
}

# Add google_compute_subnetwork_iam_member stanza here to add user-assigned service account and also Dataflow Service Account
resource "google_compute_subnetwork_iam_binding" "df-iam-sharedvpc" {
  project = var.host_project
  region = var.region
  subnetwork = var.subnet
  role = "roles/compute.networkUser"
  members = [
    "serviceAccount:${local.dataflow_service_service_account}",
    "serviceAccount:${local.dataflow_worker_service_account}",
    ]
}

# So dataflow worker can access the secret for the HEC token
resource "google_secret_manager_secret_iam_binding" "binding" {
  project = var.project
  secret_id = var.secret_name
  role = "roles/secretmanager.secretAccessor"
  members = [
    "serviceAccount:${local.dataflow_worker_service_account}",
  ]
}


# To deploy Dataflow jobs, terraform caller identity must have permission to impersonate
# worker service account in order to attach that service account to Compute Engine VMs.
# In case of user-managed worker service account, add necessary permission over new service account,
# (id: google_service_account.dataflow_worker_service_account[0].id)
# In case of default worker service account (i.e. Compute Engine default service account), caller
# must have permission to impersonate Compute Engine default service account; otherwise, job
# deployment will return an error. For security purposes, we do not modify access to existing
# default Compute Engine service account
resource "google_service_account_iam_binding" "terraform_caller_impersonate_dataflow_worker" {
  count = (var.dataflow_worker_service_account != "") ? 1 : 0
  service_account_id = google_service_account.dataflow_worker_service_account[0].id
  role = "roles/iam.serviceAccountUser"

  members = [
      "user:${data.google_client_openid_userinfo.provider_identity.email}"
  ]
}