#! /usr/bin/env bash

destination_path=$(realpath "$1")

SCRIPT_DIR=$(realpath $(dirname $0))

templates_dir="$SCRIPT_DIR/../infrastructure-templates"

[ -d "$destination_path" ] && echo "Directory $destination_path already exists" && exit 1

infra_template=$(ls "$templates_dir" | fzf --prompt "Choose An Infrastructure template")

mkdir -p "$destination_path"

pushd "$destination_path" >/dev/null 2>&1 || exit
mkdir -p .secrets

touch .secrets/env

cat >Taskfile.yml <<EOF
version: 3

dotenv:
  - .secrets/env

vars:
  Varsfile: ".secrets/varfile.json"

tasks:
  sync-from-template:
    vars:
      InfrastructureTemplate: $(realpath $SCRIPT_DIR/../infrastructure-templates/${infra_template} --relative-to=$destination_path)
    env:
      SHELL: bash
    silent: true
    cmds:
      - chmod -f 600 ./*.tf | true
      - cp {{.InfrastructureTemplate}}/*.tf ./
      - chmod 400 ./*.tf
      - echo "sync complete"

  init:
    cmds:
      - terraform init
    silent: true

  plan:
    dir: ./
    vars:
      PlanOutput: ".secrets/plan.out"
    cmds:
      - cat ./varfile.template.yml | envsubst | yq > {{.Varsfile}}
      - terraform plan --var-file "{{.Varsfile}}" --out "{{.PlanOutput}}"

  apply:
    dir: ./
    dotenv:
      - .secrets/env
    vars:
      PlanOutput: ".secrets/plan.out"
    cmds:
      - terraform apply "{{.PlanOutput}}"

  validate:
    dir: ./
    cmds:
      - terraform validate  -var-file={{.Varsfile}}

  destroy:
    dir: ./
    dotenv:
      - .secrets/env
    vars:
      PlanOutput: ".secrets/plan.destroy.out"
    cmds:
      - cat ./varfile.template.yml | envsubst | yq > {{.Varsfile}}
      - terraform plan --var-file={{.Varsfile}} --destroy --out "{{.PlanOutput}}"
      - terraform apply "{{.PlanOutput}}"
EOF

popd
