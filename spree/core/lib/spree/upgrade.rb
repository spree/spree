module Spree
  # Reads the upgrade manifests shipped inside spree_core — the list of data
  # steps an installation must run after `db:migrate` for a given release
  # boundary (docs/plans/6.0-maintenance-tasks.md).
  #
  # Extracted from lib/tasks/upgrade.rake so the dashboard and the maintenance
  # task runner can read the same manifests the rake walk does; the rake file
  # keeps the walking and printing.
  module Upgrade
    # The first release whose upgrade steps run as maintenance tasks. Nothing
    # recorded the steps of earlier releases, so the dashboard starts here; the
    # command line still walks every manifest.
    FIRST_TRACKED_RELEASE = '6.0'.freeze

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

    # Every manifest with its steps loaded, in walk order. Read once per
    # process: the files ship inside the gem and change only with a deploy.
    #
    # @return [Array<Hash>]
    def self.manifests
      @manifests ||= available_manifests.map do |entry|
        YAML.safe_load_file(File.join(entry[:dir], 'manifest.yml')).freeze
      end.freeze
    end

    # Every step of every manifest, in walk order, each carrying the manifest
    # boundary it belongs to so callers can group without re-reading the files.
    #
    # @return [Array<Hash>]
    def self.steps
      @steps ||= manifests.flat_map do |manifest|
        manifest['steps'].map do |step|
          step.merge('from' => manifest['from'], 'to' => manifest['to'], 'docs' => manifest['docs'])
        end
      end.freeze
    end

    # Whether a step belongs to a release whose runs are recorded, and so has a
    # place in the dashboard's checklist.
    #
    # @param step [Hash] a manifest step
    # @return [Boolean]
    def self.tracked?(step)
      compare(step['to'], FIRST_TRACKED_RELEASE) >= 0
    end

    # The task a step runs: its own class, or the shared runner for a step
    # that names a rake task.
    #
    # @param step [Hash] a manifest step
    # @return [String] a task class name
    def self.task_class_name(step)
      step['task_class'] || 'Spree::MaintenanceTasks::UpgradeStep'
    end

    # The arguments that start a step's task: a rake-backed step is named by
    # its id, so the shared runner knows which rake task to invoke.
    #
    # @param step [Hash] a manifest step
    # @return [Hash]
    def self.task_arguments(step)
      step['task_class'] ? {} : { 'step_id' => step['id'] }
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
    # showing the one boundary that is almost certainly right. A store that
    # skipped releases runs the earlier steps from the command line, which
    # walks every manifest whatever the boundary.
    #
    # @return [String, nil]
    def self.completed_boundary
      Spree::UpgradeRecord.current_version || previous_boundary
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
    # history of past releases describes anything real for it. True again
    # once a later release ships steps it has not run.
    #
    # @return [Boolean]
    def self.relevant?
      !Spree::UpgradeRecord.exists? || Spree::UpgradeRecord.upgraded? || pending_steps.any?
    end

    # Whether a step can run here. An optional step belongs to a gem that may
    # not be installed — a payment gateway, for instance — and is skipped
    # where it is absent rather than offered as work that cannot start.
    #
    # @param step [Hash] a manifest step
    # @return [Boolean]
    def self.available?(step)
      return true unless step['optional']
      return Spree::MaintenanceTask.find_registered(step['task_class']).present? if step['task_class']

      Spree::MaintenanceTask.new.rake_file_defining(step['task']).present?
    end

    # Steps this installation still has to run: every manifest above the
    # boundary it has completed, up to and including the installed version.
    #
    # @return [Array<Hash>]
    def self.pending_steps
      boundary = completed_boundary

      steps.select do |step|
        next false if compare(step['to'], installed_minor_version) > 0
        next false unless available?(step)
        next true if boundary.nil?

        compare(step['from'], boundary) >= 0
      end
    end

    # Steps of manifests below the completed boundary — the ones a fresh or
    # already-upgraded installation does not need. When the boundary was
    # assumed rather than recorded the dashboard says so, and points a store
    # that skipped a release at the command line, which still runs them.
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
