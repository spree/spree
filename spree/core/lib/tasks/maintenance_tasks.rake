# frozen_string_literal: true

# Command-line entry to the same runner the dashboard drives, so a shell run
# is audited exactly like an operator's (docs/plans/6.0-maintenance-tasks.md).
#
#   bin/rake spree:maintenance_tasks:list
#   bin/rake "spree:maintenance_tasks:perform[Spree::MaintenanceTasks::Upgrade::BackfillOrderMarkets]"
#   ARGS='market_id=mkt_1 batch_size=200' DRY_RUN=1 bin/rake "spree:maintenance_tasks:perform[...]"
namespace :spree do
  namespace :maintenance_tasks do
    desc 'List the registered maintenance tasks'
    task list: :environment do
      tasks = Spree::MaintenanceTask.registered_classes

      if tasks.empty?
        puts '  No maintenance tasks are registered.'
        next
      end

      tasks.each do |task_class|
        puts "  #{task_class.name}"
        puts "    #{task_class.resolved_description}" if task_class.resolved_description.present?

        task_class.parameters_schema.each do |parameter|
          required = parameter[:required] ? ' (required)' : ''
          options = parameter[:options] ? " one of: #{parameter[:options].join(', ')}" : ''
          puts "    - #{parameter[:name]}: #{parameter[:type]}#{required}#{options}"
        end
      end
    end

    desc 'Run a maintenance task synchronously'
    task :perform, [:task_name] => :environment do |_task, args|
      task_name = args[:task_name] || ENV['TASK']
      abort '  Pass a task name: rake "spree:maintenance_tasks:perform[Your::Task]"' if task_name.blank?

      result = Spree::MaintenanceTasks::Start.call(
        task_name: task_name,
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
        abort '  The run failed. Fix the cause and resume it from the dashboard, or re-run this task.'
      end
    end
  end
end
