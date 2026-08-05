#!/usr/bin/env python3

# Fallback port of update-charts.mjs for runners without Node (Spacelift's Alpine
# image ships python3 but no node). Output must stay byte-identical to the .mjs
# version: the chart directory hash in prepare.sh feeds the Helm chart version, so
# any formatting drift shows up as a spurious release upgrade.
# Keep the ignore list and category mapping in sync with update-charts.mjs.

import json
import os
import sys

SCRIPT_NAME = os.path.basename(sys.argv[0])
USAGE = (
    f"Usage: python3 {SCRIPT_NAME} <input-json> [workspace-directory]\n"
    "  <input-json>          Path to a JSON file containing input parameters.\n"
    "  [workspace-directory] Optional path to the repository root. Defaults to current directory."
)

IGNORED_SERVICES = [
    "embassy",
    "prometheus-ecs-discovery",
    "redis-streams-exporter",
    "alb-log-parser",
    "minio",
]

CHART_CATEGORIES = {
    "monitoring": "paragon-monitoring",
    "logging": "paragon-logging",
    "onPrem": "paragon-onprem",
}


def exit_with_error(message):
    print(message, file=sys.stderr)
    sys.exit(1)


def exit_with_usage_error(message):
    exit_with_error(f"{message}\n\n{USAGE}")


def verify_script_args():
    args = sys.argv[1:]
    input_file_path = args[0] if args else None
    workspace_directory = args[1] if len(args) > 1 else "."

    if not input_file_path:
        exit_with_usage_error("Missing required argument: <input.json>")
    if not os.path.exists(input_file_path):
        exit_with_usage_error(f"Specified input file does not exist: {input_file_path}")
    if not os.path.exists(workspace_directory):
        exit_with_usage_error(f"Workspace directory does not exist: {workspace_directory}")
    if not os.path.isdir(os.path.join(workspace_directory, "charts")):
        exit_with_usage_error(
            f"The 'charts' directory was not found in {workspace_directory}. "
            "Please pass the correct path to the repository root as the second argument."
        )

    return input_file_path, workspace_directory


def get_chart_subdir(service_name, service_category):
    if service_name in ("openobserve", "fluent-bit"):
        return CHART_CATEGORIES["logging"]
    if service_category == "monitor":
        return CHART_CATEGORIES["monitoring"]
    return CHART_CATEGORIES["onPrem"]


def write_chart_fixtures(service):
    service_name = service["name"]
    subdir = get_chart_subdir(service_name, service.get("category"))

    flattened = dict(service)
    flattened["envKeys"] = sorted(service["envKeys"])
    flattened["secretKeys"] = sorted(service["secretKeys"])

    print(f"Writing chart fixtures for service: {service_name}")
    chart_directory = os.path.join("charts", subdir, "charts", service_name)
    chart_yaml_path = os.path.join(chart_directory, "Chart.yaml")

    if not os.path.exists(chart_yaml_path):
        print(f"  Helm chart does not exist for service {service_name}!", file=sys.stderr)
        print(f"  Expected path: {chart_yaml_path}", file=sys.stderr)
        print("  Are you missing a helm chart for a newly-added service?", file=sys.stderr)
        print(
            f"  Please create the chart or add the service to the ignore list in {SCRIPT_NAME}.",
            file=sys.stderr,
        )
        return False

    print(f"  Found chart directory: {chart_directory}")
    files_dir = os.path.join(chart_directory, "files")
    os.makedirs(files_dir, exist_ok=True)
    # JSON.stringify(value, null, 2) equivalent: 2-space indent, ": " / ", "
    # separators, literal UTF-8, no trailing newline.
    with open(os.path.join(files_dir, "service-inputs.json"), "w", encoding="utf-8") as handle:
        handle.write(json.dumps(flattened, indent=2, ensure_ascii=False))
    return True


def main():
    input_file_path, workspace_directory = verify_script_args()

    print(f"Generating Helm charts using parameters from: {input_file_path}")
    print(f"Using workspace directory: {os.path.abspath(workspace_directory)}")

    try:
        with open(input_file_path, encoding="utf-8") as handle:
            update_params = json.load(handle)
    except (OSError, ValueError) as error:
        exit_with_error(f"Failed to read or parse input file: {error}. Path: {input_file_path}")

    services = update_params["inputs"]["services"]
    print(
        "Parsed input parameters:",
        {
            "version": update_params.get("version"),
            "platformEnv": update_params.get("platformEnv"),
            "serviceCount": len(services),
        },
    )

    failures = 0
    for service in services:
        if service["name"] in IGNORED_SERVICES:
            print(f"Skipping ignored service: {service['name']}")
            continue
        if not write_chart_fixtures(service):
            failures += 1

    if failures:
        exit_with_error(f"Failed to write chart fixtures for {failures} service(s).")

    print("Successfully wrote chart fixtures for all services.")


main()
