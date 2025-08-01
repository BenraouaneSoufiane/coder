terraform {
  required_providers {
    coder = {
      source  = "coder/coder"
      version = "~> 2.5"
    }
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

// This module is a terraform no-op. It contains 5mb worth of files to test
// Coder's behavior dealing with larger modules. This is included to test
// protobuf message size limits and the performance of module loading.
//
// In reality, modules might have accidental bloat from non-terraform files such
// as images & documentation.
module "large-5mb-module" {
  source = "git::https://github.com/coder/large-module.git"
}

locals {
  // These are cluster service addresses mapped to Tailscale nodes. Ask Dean or
  // Kyle for help.
  docker_host = {
    ""              = "tcp://dogfood-ts-cdr-dev.tailscale.svc.cluster.local:2375"
    "us-pittsburgh" = "tcp://dogfood-ts-cdr-dev.tailscale.svc.cluster.local:2375"
    // For legacy reasons, this host is labelled `eu-helsinki` but it's
    // actually in Germany now.
    "eu-helsinki" = "tcp://katerose-fsn-cdr-dev.tailscale.svc.cluster.local:2375"
    "ap-sydney"   = "tcp://wolfgang-syd-cdr-dev.tailscale.svc.cluster.local:2375"
    "sa-saopaulo" = "tcp://oberstein-sao-cdr-dev.tailscale.svc.cluster.local:2375"
    "za-cpt"      = "tcp://schonkopf-cpt-cdr-dev.tailscale.svc.cluster.local:2375"
  }

  repo_base_dir  = data.coder_parameter.repo_base_dir.value == "~" ? "/home/coder" : replace(data.coder_parameter.repo_base_dir.value, "/^~\\//", "/home/coder/")
  repo_dir       = replace(try(module.git-clone[0].repo_dir, ""), "/^~\\//", "/home/coder/")
  container_name = "coder-${data.coder_workspace_owner.me.name}-${lower(data.coder_workspace.me.name)}"
}

data "coder_workspace_preset" "cpt" {
  name = "Cape Town"
  parameters = {
    (data.coder_parameter.region.name)                   = "za-cpt"
    (data.coder_parameter.image_type.name)               = "codercom/oss-dogfood:latest"
    (data.coder_parameter.repo_base_dir.name)            = "~"
    (data.coder_parameter.res_mon_memory_threshold.name) = 80
    (data.coder_parameter.res_mon_volume_threshold.name) = 90
    (data.coder_parameter.res_mon_volume_path.name)      = "/home/coder"
  }
  prebuilds {
    instances = 1
  }
}

data "coder_workspace_preset" "pittsburgh" {
  name = "Pittsburgh"
  parameters = {
    (data.coder_parameter.region.name)                   = "us-pittsburgh"
    (data.coder_parameter.image_type.name)               = "codercom/oss-dogfood:latest"
    (data.coder_parameter.repo_base_dir.name)            = "~"
    (data.coder_parameter.res_mon_memory_threshold.name) = 80
    (data.coder_parameter.res_mon_volume_threshold.name) = 90
    (data.coder_parameter.res_mon_volume_path.name)      = "/home/coder"
  }
  prebuilds {
    instances = 2
  }
}

data "coder_workspace_preset" "falkenstein" {
  name = "Falkenstein"
  parameters = {
    (data.coder_parameter.region.name)                   = "eu-helsinki"
    (data.coder_parameter.image_type.name)               = "codercom/oss-dogfood:latest"
    (data.coder_parameter.repo_base_dir.name)            = "~"
    (data.coder_parameter.res_mon_memory_threshold.name) = 80
    (data.coder_parameter.res_mon_volume_threshold.name) = 90
    (data.coder_parameter.res_mon_volume_path.name)      = "/home/coder"
  }
  prebuilds {
    instances = 1
  }
}

data "coder_workspace_preset" "sydney" {
  name = "Sydney"
  parameters = {
    (data.coder_parameter.region.name)                   = "ap-sydney"
    (data.coder_parameter.image_type.name)               = "codercom/oss-dogfood:latest"
    (data.coder_parameter.repo_base_dir.name)            = "~"
    (data.coder_parameter.res_mon_memory_threshold.name) = 80
    (data.coder_parameter.res_mon_volume_threshold.name) = 90
    (data.coder_parameter.res_mon_volume_path.name)      = "/home/coder"
  }
  prebuilds {
    instances = 1
  }
}

data "coder_workspace_preset" "saopaulo" {
  name = "São Paulo"
  parameters = {
    (data.coder_parameter.region.name)                   = "sa-saopaulo"
    (data.coder_parameter.image_type.name)               = "codercom/oss-dogfood:latest"
    (data.coder_parameter.repo_base_dir.name)            = "~"
    (data.coder_parameter.res_mon_memory_threshold.name) = 80
    (data.coder_parameter.res_mon_volume_threshold.name) = 90
    (data.coder_parameter.res_mon_volume_path.name)      = "/home/coder"
  }
  prebuilds {
    instances = 1
  }
}

data "coder_parameter" "repo_base_dir" {
  type        = "string"
  name        = "Coder Repository Base Directory"
  default     = "~"
  description = "The directory specified will be created (if missing) and [coder/coder](https://github.com/coder/coder) will be automatically cloned into [base directory]/coder 🪄."
  mutable     = true
}

data "coder_parameter" "image_type" {
  type        = "string"
  name        = "Coder Image"
  default     = "codercom/oss-dogfood:latest"
  description = "The Docker image used to run your workspace. Choose between nix and non-nix images."
  option {
    icon  = "/icon/coder.svg"
    name  = "Dogfood (Default)"
    value = "codercom/oss-dogfood:latest"
  }
  option {
    icon  = "/icon/nix.svg"
    name  = "Dogfood Nix (Experimental)"
    value = "codercom/oss-dogfood-nix:latest"
  }
}

locals {
  default_regions = {
    // keys should match group names
    "north-america" : "us-pittsburgh"
    "europe" : "eu-helsinki"
    "australia" : "ap-sydney"
    "south-america" : "sa-saopaulo"
    "africa" : "za-cpt"
  }

  user_groups = data.coder_workspace_owner.me.groups
  user_region = coalescelist([
    for g in local.user_groups :
    local.default_regions[g] if contains(keys(local.default_regions), g)
  ], ["us-pittsburgh"])[0]
}


data "coder_parameter" "region" {
  type    = "string"
  name    = "Region"
  icon    = "/emojis/1f30e.png"
  default = local.user_region
  option {
    icon  = "/emojis/1f1fa-1f1f8.png"
    name  = "Pittsburgh"
    value = "us-pittsburgh"
  }
  option {
    icon = "/emojis/1f1e9-1f1ea.png"
    name = "Falkenstein"
    // For legacy reasons, this host is labelled `eu-helsinki` but it's
    // actually in Germany now.
    value = "eu-helsinki"
  }
  option {
    icon  = "/emojis/1f1e6-1f1fa.png"
    name  = "Sydney"
    value = "ap-sydney"
  }
  option {
    icon  = "/emojis/1f1e7-1f1f7.png"
    name  = "São Paulo"
    value = "sa-saopaulo"
  }
  option {
    icon  = "/emojis/1f1ff-1f1e6.png"
    name  = "Cape Town"
    value = "za-cpt"
  }
}

data "coder_parameter" "res_mon_memory_threshold" {
  type        = "number"
  name        = "Memory usage threshold"
  default     = 80
  description = "The memory usage threshold used in resources monitoring to trigger notifications."
  mutable     = true
  validation {
    min = 0
    max = 100
  }
}

data "coder_parameter" "res_mon_volume_threshold" {
  type        = "number"
  name        = "Volume usage threshold"
  default     = 90
  description = "The volume usage threshold used in resources monitoring to trigger notifications."
  mutable     = true
  validation {
    min = 0
    max = 100
  }
}

data "coder_parameter" "res_mon_volume_path" {
  type        = "string"
  name        = "Volume path"
  default     = "/home/coder"
  description = "The path monitored in resources monitoring to trigger notifications."
  mutable     = true
}

data "coder_parameter" "devcontainer_autostart" {
  type        = "bool"
  name        = "Automatically start devcontainer for coder/coder"
  default     = false
  description = "If enabled, a devcontainer will be automatically started for the [coder/coder](https://github.com/coder/coder) repository."
  mutable     = true
}

provider "docker" {
  host = lookup(local.docker_host, data.coder_parameter.region.value)
}

provider "coder" {}

data "coder_external_auth" "github" {
  id = "github"
}

data "coder_workspace" "me" {}
data "coder_workspace_owner" "me" {}
data "coder_workspace_tags" "tags" {
  tags = {
    "cluster" : "dogfood-v2"
    "env" : "gke"
  }
}

module "slackme" {
  count            = data.coder_workspace.me.start_count
  source           = "dev.registry.coder.com/coder/slackme/coder"
  version          = "1.0.30"
  agent_id         = coder_agent.dev.id
  auth_provider_id = "slack"
}

module "dotfiles" {
  count    = data.coder_workspace.me.start_count
  source   = "dev.registry.coder.com/coder/dotfiles/coder"
  version  = "1.2.0"
  agent_id = coder_agent.dev.id
}

module "git-clone" {
  count    = data.coder_workspace.me.start_count
  source   = "dev.registry.coder.com/coder/git-clone/coder"
  version  = "1.1.0"
  agent_id = coder_agent.dev.id
  url      = "https://github.com/coder/coder"
  base_dir = local.repo_base_dir
}

module "personalize" {
  count    = data.coder_workspace.me.start_count
  source   = "dev.registry.coder.com/coder/personalize/coder"
  version  = "1.0.30"
  agent_id = coder_agent.dev.id
}

module "code-server" {
  count                   = data.coder_workspace.me.start_count
  source                  = "dev.registry.coder.com/coder/code-server/coder"
  version                 = "1.3.0"
  agent_id                = coder_agent.dev.id
  folder                  = local.repo_dir
  auto_install_extensions = true
  group                   = "Web Editors"
}

module "vscode-web" {
  count                   = data.coder_workspace.me.start_count
  source                  = "dev.registry.coder.com/coder/vscode-web/coder"
  version                 = "1.3.0"
  agent_id                = coder_agent.dev.id
  folder                  = local.repo_dir
  extensions              = ["github.copilot"]
  auto_install_extensions = true # will install extensions from the repos .vscode/extensions.json file
  accept_license          = true
  group                   = "Web Editors"
}

module "jetbrains" {
  count         = data.coder_workspace.me.start_count
  source        = "dev.registry.coder.com/coder/jetbrains/coder"
  version       = "1.0.0"
  agent_id      = coder_agent.dev.id
  agent_name    = "dev"
  folder        = local.repo_dir
  major_version = "latest"
}

module "filebrowser" {
  count      = data.coder_workspace.me.start_count
  source     = "dev.registry.coder.com/coder/filebrowser/coder"
  version    = "1.1.1"
  agent_id   = coder_agent.dev.id
  agent_name = "dev"
}

module "coder-login" {
  count    = data.coder_workspace.me.start_count
  source   = "dev.registry.coder.com/coder/coder-login/coder"
  version  = "1.0.30"
  agent_id = coder_agent.dev.id
}

module "cursor" {
  count    = data.coder_workspace.me.start_count
  source   = "dev.registry.coder.com/coder/cursor/coder"
  version  = "1.2.0"
  agent_id = coder_agent.dev.id
  folder   = local.repo_dir
}

module "windsurf" {
  count    = data.coder_workspace.me.start_count
  source   = "dev.registry.coder.com/coder/windsurf/coder"
  version  = "1.1.0"
  agent_id = coder_agent.dev.id
  folder   = local.repo_dir
}

module "zed" {
  count      = data.coder_workspace.me.start_count
  source     = "dev.registry.coder.com/coder/zed/coder"
  version    = "1.0.0"
  agent_id   = coder_agent.dev.id
  agent_name = "dev"
  folder     = local.repo_dir
}

module "jetbrains-fleet" {
  count      = data.coder_workspace.me.start_count
  source     = "registry.coder.com/coder/jetbrains-fleet/coder"
  version    = "1.0.1"
  agent_id   = coder_agent.dev.id
  agent_name = "dev"
  folder     = local.repo_dir
}

module "devcontainers-cli" {
  count    = data.coder_workspace.me.start_count
  source   = "dev.registry.coder.com/modules/devcontainers-cli/coder"
  version  = ">= 1.0.0"
  agent_id = coder_agent.dev.id
}

resource "coder_agent" "dev" {
  arch = "amd64"
  os   = "linux"
  dir  = local.repo_dir
  env = {
    OIDC_TOKEN : data.coder_workspace_owner.me.oidc_access_token,
  }
  startup_script_behavior = "blocking"

  # The following metadata blocks are optional. They are used to display
  # information about your workspace in the dashboard. You can remove them
  # if you don't want to display any information.
  metadata {
    display_name = "CPU Usage"
    key          = "cpu_usage"
    order        = 0
    script       = "coder stat cpu"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage"
    key          = "ram_usage"
    order        = 1
    script       = "coder stat mem"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "CPU Usage (Host)"
    key          = "cpu_usage_host"
    order        = 2
    script       = "coder stat cpu --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "RAM Usage (Host)"
    key          = "ram_usage_host"
    order        = 3
    script       = "coder stat mem --host"
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Swap Usage (Host)"
    key          = "swap_usage_host"
    order        = 4
    script       = <<EOT
      #!/usr/bin/env bash
      echo "$(free -b | awk '/^Swap/ { printf("%.1f/%.1f", $3/1024.0/1024.0/1024.0, $2/1024.0/1024.0/1024.0) }') GiB"
    EOT
    interval     = 10
    timeout      = 1
  }

  metadata {
    display_name = "Load Average (Host)"
    key          = "load_host"
    order        = 5
    # get load avg scaled by number of cores
    script   = <<EOT
      #!/usr/bin/env bash
      echo "`cat /proc/loadavg | awk '{ print $1 }'` `nproc`" | awk '{ printf "%0.2f", $1/$2 }'
    EOT
    interval = 60
    timeout  = 1
  }

  metadata {
    display_name = "Disk Usage (Host)"
    key          = "disk_host"
    order        = 6
    script       = "coder stat disk --path /"
    interval     = 600
    timeout      = 10
  }

  metadata {
    display_name = "Word of the Day"
    key          = "word"
    order        = 7
    script       = <<EOT
      #!/usr/bin/env bash
      curl -o - --silent https://www.merriam-webster.com/word-of-the-day 2>&1 | awk ' $0 ~ "Word of the Day: [A-z]+" { print $5; exit }'
    EOT
    interval     = 86400
    timeout      = 5
  }

  resources_monitoring {
    memory {
      enabled   = true
      threshold = data.coder_parameter.res_mon_memory_threshold.value
    }
    volume {
      enabled   = true
      threshold = data.coder_parameter.res_mon_volume_threshold.value
      path      = data.coder_parameter.res_mon_volume_path.value
    }
    volume {
      enabled   = true
      threshold = data.coder_parameter.res_mon_volume_threshold.value
      path      = "/var/lib/docker"
    }
  }

  startup_script = <<-EOT
    #!/usr/bin/env bash
    set -eux -o pipefail

    # Allow synchronization between scripts.
    trap 'touch /tmp/.coder-startup-script.done' EXIT

    # Increase the shutdown timeout of the docker service for improved cleanup.
    # The 240 was picked as it's lower than the 300 seconds we set for the
    # container shutdown grace period.
    sudo sh -c 'jq ". += {\"shutdown-timeout\": 240}" /etc/docker/daemon.json > /tmp/daemon.json.new && mv /tmp/daemon.json.new /etc/docker/daemon.json'
    # Start Docker service
    sudo service docker start
    # Install playwright dependencies
    # We want to use the playwright version from site/package.json
    # Check if the directory exists At workspace creation as the coder_script runs in parallel so clone might not exist yet.
    while ! [[ -f "${local.repo_dir}/site/package.json" ]]; do
      sleep 1
    done
    cd "${local.repo_dir}" && make clean
    cd "${local.repo_dir}/site" && pnpm install
  EOT

  shutdown_script = <<-EOT
    #!/usr/bin/env bash
    set -eux -o pipefail

    # Clean up the Go build cache to prevent the home volume from
    # accumulating waste and growing too large.
    go clean -cache

    # Clean up the unused resources to keep storage usage low.
    #
    # WARNING! This will remove:
    #   - all stopped containers
    #   - all networks not used by at least one container
    #   - all images without at least one container associated to them
    #   - all build cache
    docker system prune -a -f

    # Stop the Docker service to prevent errors during workspace destroy.
    sudo service docker stop
  EOT
}

resource "coder_devcontainer" "coder" {
  count            = data.coder_parameter.devcontainer_autostart.value ? data.coder_workspace.me.start_count : 0
  agent_id         = coder_agent.dev.id
  workspace_folder = local.repo_dir
}

# Add a cost so we get some quota usage in dev.coder.com
resource "coder_metadata" "home_volume" {
  resource_id = docker_volume.home_volume.id
  daily_cost  = 1
}

resource "docker_volume" "home_volume" {
  name = "coder-${data.coder_workspace.me.id}-home"
  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

resource "coder_metadata" "docker_volume" {
  resource_id = docker_volume.docker_volume.id
  hide        = true # Hide it as it is not useful to see in the UI.
}

resource "docker_volume" "docker_volume" {
  name = "coder-${data.coder_workspace.me.id}-docker"
  # Protect the volume from being deleted due to changes in attributes.
  lifecycle {
    ignore_changes = all
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  # This field becomes outdated if the workspace is renamed but can
  # be useful for debugging or cleaning out dangling volumes.
  labels {
    label = "coder.workspace_name_at_creation"
    value = data.coder_workspace.me.name
  }
}

data "docker_registry_image" "dogfood" {
  name = data.coder_parameter.image_type.value
}

resource "docker_image" "dogfood" {
  name = "${data.coder_parameter.image_type.value}@${data.docker_registry_image.dogfood.sha256_digest}"
  pull_triggers = [
    data.docker_registry_image.dogfood.sha256_digest,
    sha1(join("", [for f in fileset(path.module, "files/*") : filesha1(f)])),
    filesha1("Dockerfile"),
    filesha1("nix.hash"),
  ]
  keep_locally = true
}

resource "docker_container" "workspace" {
  lifecycle {
    // Ignore changes that would invalidate prebuilds
    ignore_changes = [
      name,
      hostname,
      labels,
    ]
  }
  count = data.coder_workspace.me.start_count
  image = docker_image.dogfood.name
  name  = local.container_name
  # Hostname makes the shell more user friendly: coder@my-workspace:~$
  hostname = data.coder_workspace.me.name
  # Use the docker gateway if the access URL is 127.0.0.1
  entrypoint = ["sh", "-c", coder_agent.dev.init_script]
  # CPU limits are unnecessary since Docker will load balance automatically
  memory  = data.coder_workspace_owner.me.name == "code-asher" ? 65536 : 32768
  runtime = "sysbox-runc"

  # Ensure the workspace is given time to:
  # - Execute shutdown scripts
  # - Stop the in workspace Docker daemon
  # - Stop the container, especially when using devcontainers,
  #   deleting the overlay filesystem can take a while.
  destroy_grace_seconds = 300
  stop_timeout          = 300
  stop_signal           = "SIGINT"

  env = [
    "CODER_AGENT_TOKEN=${coder_agent.dev.token}",
    "USE_CAP_NET_ADMIN=true",
    "CODER_PROC_PRIO_MGMT=1",
    "CODER_PROC_OOM_SCORE=10",
    "CODER_PROC_NICE_SCORE=1",
    "CODER_AGENT_DEVCONTAINERS_ENABLE=1",
  ]
  host {
    host = "host.docker.internal"
    ip   = "host-gateway"
  }
  volumes {
    container_path = "/home/coder/"
    volume_name    = docker_volume.home_volume.name
    read_only      = false
  }
  volumes {
    container_path = "/var/lib/docker/"
    volume_name    = docker_volume.docker_volume.name
    read_only      = false
  }
  capabilities {
    add = ["CAP_NET_ADMIN", "CAP_SYS_NICE"]
  }
  # Add labels in Docker to keep track of orphan resources.
  labels {
    label = "coder.owner"
    value = data.coder_workspace_owner.me.name
  }
  labels {
    label = "coder.owner_id"
    value = data.coder_workspace_owner.me.id
  }
  labels {
    label = "coder.workspace_id"
    value = data.coder_workspace.me.id
  }
  labels {
    label = "coder.workspace_name"
    value = data.coder_workspace.me.name
  }
}

resource "coder_metadata" "container_info" {
  count       = data.coder_workspace.me.start_count
  resource_id = docker_container.workspace[0].id
  item {
    key   = "memory"
    value = docker_container.workspace[0].memory
  }
  item {
    key   = "runtime"
    value = docker_container.workspace[0].runtime
  }
  item {
    key   = "region"
    value = data.coder_parameter.region.option[index(data.coder_parameter.region.option.*.value, data.coder_parameter.region.value)].name
  }
}
