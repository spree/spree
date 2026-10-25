# frozen_string_literal: true

# Command-line entry to the same runner the dashboard drives, so a shell run
# is audited exactly like an operator's (docs/plans/6.0-maintenance-tasks.md).
#
#   bin/rake "spree:maintenance_tasks:perform[backfill_order_markets]"
#   DRY_RUN=1 bin/rake "spree:maintenance_tasks:perform[capture_methods]"
#   ARGS='batch_size=200' bin/rake "spree:maintenance_tasks:perform[deliveries]"
namespace :spree do
  namespace :maintenance_tasks do
    desc 'Run a maintenance task synchronously'
    task :perform, [:task_name] => :environment do |_task, args|
      task_name = args[:task_name] || ENV['TASK']
      abort '  Pass a task name: rake "spree:maintenance_tasks:perform[Your::Task]"' if task_name.blank?

      # Either the class name or the short name the dashboard shows.
      lookup = Spree::MaintenanceTask.find_registered(task_name) ? { task_name: task_name } : { api_type: task_name }

      result = Spree::MaintenanceTasks::Start.call(
        **lookup,
        arguments: Spree::MaintenanceTasks::ArgumentParser.parse(ENV['ARGS']),
        dry_run: ENV['DRY_RUN'] == '1',
        initiated_via: 'cli',
        inline: true
      )

      abort "  #{result.error}" if result.failure?

      run = result.value.reload
      puts "  #{run.task_name}: #{run.status} — #{run.tick_count} processed#{run.dry_run? ? ' (dry run)' : ''}"
      run.tallies.each { |key, value| puts "    #{key}: #{value}" }

      if run.errored?
        puts "  #{run.error_class}: #{run.error_message}"
        abort '  The run failed. Fix the cause, then re-run this task.'
      end
    end
  end
end
