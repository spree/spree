module Spree
  module MaintenanceTasks
    # Runs one rake-backed step of an upgrade manifest, so a shell walk and a
    # dashboard run leave the same audit record
    # (docs/plans/6.0-maintenance-tasks.md).
    #
    # Released manifests (5.4→5.5, 5.5→5.6) name rake tasks, and their steps
    # stay that way: the task names have shipped, so operators may have scripted
    # them. This wrapper gives those steps a run row without rewriting them.
    # Steps of unreleased manifests are task classes in their own right and are
    # named directly by the manifest.
    class UpgradeStep < Spree::MaintenanceTask
      description 'maintenance_tasks.upgrade_step.description'
      no_collection

      attribute :step_id, :string
      validates :step_id, presence: true

      validate :step_must_exist

      def process
        load_engine_rake_tasks

        step = manifest_step
        rake_task = ::Rake::Task[step.fetch('task')]
        rake_task.reenable
        rake_task.invoke

        tally(:completed_steps)
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
