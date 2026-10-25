module Spree
  module MaintenanceTasks
    # Runs one rake-backed step of an upgrade manifest, so a shell walk and a
    # dashboard run leave the same audit record
    # (docs/plans/6.0-maintenance-tasks.md).
    #
    # Every one-pass step names its rake task in the manifest and runs here, so
    # the rake body stays the only implementation. A step gets a task class of
    # its own only when it walks rows (progress, resume, dry run) or asks the
    # operator for parameters.
    class UpgradeStep < Spree::MaintenanceTask
      no_collection

      attribute :step_id, :string
      validates :step_id, presence: true

      validate :step_must_exist

      def process
        invoke_rake_task(manifest_step.fetch('task'))
      end

      # The manifest entry this run is executing, resolved across every
      # manifest rather than a fixed one — the walker may be part way through a
      # multi-release upgrade.
      #
      # @return [Hash, nil]
      def manifest_step
        @manifest_step ||= Spree::Upgrade.find_step(step_id)
      end

      private

      def step_must_exist
        return if step_id.blank?
        return if manifest_step.present?

        errors.add(:step_id, "no upgrade step with id #{step_id}")
      end
    end
  end
end
