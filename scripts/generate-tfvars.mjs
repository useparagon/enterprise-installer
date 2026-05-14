#!/usr/bin/env node

import { existsSync, readFileSync, writeFileSync } from "fs";
import { basename } from "path";

const SCRIPT_NAME = basename(process.argv[1]);
const USAGE = `Usage: node ${SCRIPT_NAME} <variables.tf> <output.tfvars> [provider]\n` +
  "  <variables.tf>    Path to a Terraform variables file.\n" +
  "  <output.tfvars>   Path to write generated vars.auto.tfvars.\n" +
  "  [provider]        Optional cloud provider (aws, azure, gcp, k8s).\n";

const AZURE_INFRA_RECOMMENDATIONS = [
  "",
  "# PostgreSQL Zone-Redundant HA (recommended for production).",
  "# Requires General Purpose or Memory Optimized SKUs (not Burstable).",
  "# Remove or comment out these lines if not required.",
  'postgres_redundant     = true',
  'postgres_base_sku_name = "GP_Standard_D2ads_v5"',
  "",
].join("\n");

function exitWithError(message) {
  console.error(message);
  process.exit(1);
}

function exitWithUsageError(message) {
  exitWithError(message + "\n\n" + USAGE);
}

function verifyArgs() {
  const [varsPath, outPath, provider] = process.argv.slice(2);
  if (!varsPath || !outPath) {
    exitWithUsageError("Missing required arguments.");
  }
  if (!existsSync(varsPath)) {
    exitWithUsageError(`Variables file does not exist: ${varsPath}`);
  }
  return { varsPath, outPath, provider: provider || "" };
}

function countBraces(line) {
  let count = 0;
  let inString = false;
  let escape = false;
  for (const ch of line) {
    if (escape) {
      escape = false;
      continue;
    }
    if (ch === "\\") {
      escape = true;
      continue;
    }
    if (ch === "\"") {
      inString = !inString;
      continue;
    }
    if (inString) {
      continue;
    }
    if (ch === "{") {
      count += 1;
    } else if (ch === "}") {
      count -= 1;
    }
  }
  return count;
}

function placeholder(typeValue, name) {
  if (!typeValue) {
    return `"your-${name}"`;
  }
  const t = typeValue.toLowerCase();
  if (t.includes("bool")) return "false";
  if (t.includes("number")) return "0";
  if (t.includes("list") || t.includes("set")) return "[]";
  if (t.includes("map") || t.includes("object")) return "{}";
  return `"your-${name}"`;
}

function parseVariables(varsText) {
  const lines = varsText.split(/\r?\n/);
  const variables = [];
  let inBlock = false;
  let depth = 0;
  let name = "";
  let typeValue = "";
  let hasDefault = false;

  const varStart = /^\s*variable\s+"([^"]+)"\s*{/;

  const flush = () => {
    if (!name) return;
    if (!hasDefault) {
      variables.push({ name, typeValue });
    }
  };

  for (const line of lines) {
    if (!inBlock) {
      const match = line.match(varStart);
      if (!match) {
        continue;
      }
      name = match[1];
      typeValue = "";
      hasDefault = false;
      inBlock = true;
      depth = countBraces(line);
      if (depth === 0) {
        flush();
        inBlock = false;
        name = "";
      }
      continue;
    }

    if (/^\s*type\s*=/.test(line) && !typeValue) {
      typeValue = line.replace(/^\s*type\s*=\s*/, "").trim();
    }
    if (/^\s*default\s*=/.test(line)) {
      hasDefault = true;
    }
    depth += countBraces(line);
    if (depth === 0) {
      flush();
      inBlock = false;
      name = "";
    }
  }

  return variables;
}

function generateTfvars(varsText) {
  const variables = parseVariables(varsText);
  return variables
    .map(({ name, typeValue }) => `${name} = ${placeholder(typeValue, name)}`)
    .join("\n") + (variables.length ? "\n" : "");
}

function main() {
  const { varsPath, outPath, provider } = verifyArgs();
  const varsText = readFileSync(varsPath, "utf-8");
  let output = generateTfvars(varsText);

  if (provider === "azure" && outPath.includes("/infra/")) {
    output += AZURE_INFRA_RECOMMENDATIONS;
  }

  writeFileSync(outPath, output);
}

main();
