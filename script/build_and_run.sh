#!/bin/zsh

set -euo pipefail

repo_root="${0:A:h:h}"
project_path="$repo_root/widtget.xcodeproj"
scheme="widtget app"
configuration="${WIDTGET_CONFIGURATION:-Debug}"
derived_data="${WIDTGET_DERIVED_DATA:-$repo_root/.build/DerivedData}"
action="${1:-build}"

build_args=(
  -project "$project_path"
  -scheme "$scheme"
  -configuration "$configuration"
  -destination "platform=macOS"
  -derivedDataPath "$derived_data"
)

case "$action" in
  build)
    # Agent validation does not need access to a developer certificate.
    xcodebuild "${build_args[@]}" CODE_SIGNING_ALLOWED=NO build
    ;;
  run)
    # A signed run registers the embedded WidgetKit extension with macOS.
    xcodebuild "${build_args[@]}" build

    app_path="$derived_data/Build/Products/$configuration/widtget.app"
    if [[ ! -d "$app_path" ]]; then
      print -u2 "Built app was not found at: $app_path"
      exit 1
    fi

    open "$app_path"
    ;;
  clean)
    xcodebuild "${build_args[@]}" clean
    ;;
  *)
    print -u2 "Usage: $0 [build|run|clean]"
    exit 64
    ;;
esac
