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

    # The boundary this installation has already completed, and therefore the
    # point a pending list starts from.
    #
    # Falls back to the release before the installed one when nothing has been
    # stamped: an installation running 6.0 has, by far most often, come from
    # 5.6, and showing every step of every manifest ever written is worse than
    # showing the one boundary that is almost certainly right. The fallback is
    # a guess and is reported as one — `completed_boundary_known?` is false —
    # so callers can offer the older steps rather than hide them.
    #
    # @return [String, nil]
    def self.completed_boundary
      Spree::UpgradeRecord.current_version || previous_boundary
    end

    # Whether the boundary was recorded rather than assumed.
    #
    # @return [Boolean]
    def self.completed_boundary_known?
      Spree::UpgradeRecord.current_version.present?
    end

    # The `to` of the manifest immediately below the installed version.
    #
    # @return [String, nil]
    def self.previous_boundary
      boundaries = manifests.map { |manifest| manifest['from'] }.uniq
      boundaries.select { |version| compare(version, installed_minor_version) < 0 }.
        max_by { |version| version_parts(version) }
    end

    # Whether an upgrade applies to this installation at all.
    #
    # False for a store installed fresh at its current version: it has no
    # historical data to convert, so neither the outstanding steps nor the
    # history of past releases describes anything real for it. False also once
    # every boundary is complete and nothing is outstanding.
    #
    # @return [Boolean]
    def self.relevant?
      return true unless Spree::UpgradeRecord.exists?
      return false unless Spree::UpgradeRecord.upgraded?

      true
    end

    # Steps this installation still has to run: every manifest above the
    # boundary it has completed, up to and including the installed version.
    #
    # @return [Array<Hash>]
    def self.pending_steps
      boundary = completed_boundary

      steps.select do |step|
        next false if compare(step['to'], installed_minor_version) > 0
        next true if boundary.nil?

        compare(step['from'], boundary) >= 0
      end
    end

    # Steps of manifests below the completed boundary — the ones a fresh or
    # already-upgraded installation does not need. Offered rather than hidden
    # when the boundary was assumed rather than recorded.
    #
    # @return [Array<Hash>]
    def self.superseded_steps
      boundary = completed_boundary
      return [] if boundary.nil?

      steps.select { |step| compare(step['from'], boundary) < 0 }
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
