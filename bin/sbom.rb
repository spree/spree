#!/usr/bin/env ruby
require 'json'
require 'securerandom'

# Read LicenseFinder JSON
license_data = JSON.parse(File.read("licenses.json"))

# Prepare SPDX structure
spdx_data = {
  "spdxVersion" => "SPDX-2.3",
  "dataLicense" => "CC0-1.0",
  "documentNamespace" => "http://example.com/spdxdocs/#{SecureRandom.uuid}",
  "name" => "MyProject SBOM",
  "packages" => []
}

# Transform each dependency to SPDX package
license_data["dependencies"].each do |dep|
  spdx_data["packages"] << {
    "SPDXID" => "SPDXRef-Package-#{dep['name'].gsub(/[^a-zA-Z0-9]/, '-')}-#{dep['version']}",
    "name" => dep["name"],
    "versionInfo" => dep["version"],
    "licenseDeclared" => dep["licenses"].join(", "),
    "externalRefs" => [
      {
        "referenceCategory" => "PACKAGE-MANAGER",
        "referenceType" => "purl",
        "referenceLocator" => "pkg:gem/#{dep['name']}@#{dep['version']}"
      }
    ],
    "downloadLocation" => dep["homepage"] || "NOASSERTION"
  }
end

# Write SPDX JSON
File.write("sbom_with_licenses.spdx.json", JSON.pretty_generate(spdx_data))
