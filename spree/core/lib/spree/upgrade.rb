module Spree
  # Reads the upgrade manifests shipped inside spree_core — the list of data
  # steps an installation must run after `db:migrate` for a given release
  # boundary (docs/plans/6.0-maintenance-tasks.md).
  #
  # Extracted from lib/tasks/upgrade.rake so the dashboard and the maintenance
  # task runner can read the same manifests the rake walk does; the rake file
  # keeps the walking and printing.
  module Upgrade
    # Two-segment "5.5" form of the installed Spree version.
    #
    # @return [String]
    def self.installed_minor_version
      Spree.version.split('.').first(2).join('.')
    end

    # Root directory containing N_M_to_O_P/manifest.yml files inside the
    # spree_core gem.
    #
    # @return [String]
    def self.manifests_root
      File.expand_path('upgrades', __dir__)
    end

    # All available manifest directories, parsed into { from:, to:, dir: }.
    # Sorted by `to` ascending, with `from` as a tiebreaker (smallest first)
    # for the rare case where two manifests share a `to` boundary.
    #
    # @return [Array<Hash>]
    def self.available_manifests
      Dir.glob(File.join(manifests_root, '*_to_*')).filter_map do |dir|
        name = File.basename(dir)
        match = name.match(/\A([\d_]+)_to_([\d_]+)\z/)
        next unless match

        { from: match[1].tr('_', '.'), to: match[2].tr('_', '.'), dir: dir }
      end.sort_by { |manifest| version_parts(manifest[:to]) + version_parts(manifest[:from]) }
    end

    # Every manifest with its steps loaded, in walk order.
    #
    # @return [Array<Hash>]
    def self.manifests
      available_manifests.map { |entry| YAML.safe_load_file(File.join(entry[:dir], 'manifest.yml')) }
    end

    # Every step of every manifest, in walk order, each carrying the manifest
    # boundary it belongs to so callers can group without re-reading the files.
    #
    # @return [Array<Hash>]
    def self.steps
      manifests.flat_map do |manifest|
        manifest['steps'].map do |step|
          step.merge('from' => manifest['from'], 'to' => manifest['to'], 'docs' => manifest['docs'])
        end
      end
    end

    # @param step_id [String]
    # @return [Hash, nil]
    def self.find_step(step_id)
      return nil if step_id.blank?

      steps.find { |step| step['id'] == step_id.to_s }
    end

    # Steps of manifests at or beyond the installed version — what an operator
    # upgrading to this release still has to run.
    #
    # @return [Array<Hash>]
    def self.pending_steps
      steps.select { |step| compare(step['to'], installed_minor_version) <= 0 }
    end

    def self.version_parts(version)
      version.split('.').map { |segment| Integer(segment, 10) rescue 0 }
    end

    # Compare two dotted-version strings (returns -1, 0, +1).
    def self.compare(first, second)
      version_parts(first) <=> version_parts(second)
    end
  end
end
