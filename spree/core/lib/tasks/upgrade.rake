# frozen_string_literal: true

# spree:upgrade — runs the data-backfill rake tasks shipped with the
# currently-installed spree_core. Intended to run on production (or any
# environment) after `bundle update` + `db:migrate` have already happened
# in your deploy pipeline.
#
# Walks EVERY upgrade manifest whose `to` is ≤ the installed minor version,
# in ascending order. So an app that's been on 5.3 and jumps straight to
# 5.5 still gets the 5.3→5.4 data backfills before the 5.4→5.5 ones.
# Every step in every manifest is required to be idempotent — re-running
# the task on an already-upgraded app is a safe no-op.
#
# Usage:
#   bundle exec rake spree:upgrade                 # walk all eligible manifests
#   bundle exec rake spree:upgrade DRY_RUN=1       # print plan, run nothing
#   bundle exec rake spree:upgrade STEP=channels   # run one step by id (any manifest)
#   bundle exec rake spree:upgrade TO=5.4          # cap the walk at this version
#
# Manifests live alongside this file at lib/spree/upgrades/<from>_to_<to>/
# manifest.yml and ship inside the spree_core gem.

require 'yaml'

namespace :spree do
  desc 'Run the post-deploy upgrade tasks for the installed Spree version'
  task upgrade: :environment do
    Spree::Upgrade::Runner.new(
      target_version: ENV['TO'],
      step_id:        ENV['STEP'],
      dry_run:        ENV['DRY_RUN'] == '1'
    ).call
  end
end

require 'spree/upgrade'

module Spree
  module Upgrade
    # The runner is a class (not a method) so individual concerns (selection,
    # rendering, invocation) stay separable and the plan can be inspected
    # without execution.
    class Runner
      attr_reader :target_version, :step_id, :dry_run, :target_explicit

      def initialize(target_version: nil, step_id: nil, dry_run: false)
        @target_explicit = !target_version.nil?
        @target_version  = target_version || Spree::Upgrade.installed_minor_version
        @step_id         = step_id
        @dry_run         = dry_run
      end

      def call
        manifests = eligible_manifests

        if manifests.empty?
          puts "  No upgrade manifests apply to Spree #{target_version} (installed: #{Spree::Upgrade.installed_minor_version})."
          return
        end

        if step_id
          run_single_step(manifests)
        else
          run_full_walk(manifests)
        end
      end

      private

      # In plan-mode without explicit TO, show manifests ahead of the installed
      # version — the path the operator is about to walk. Otherwise filter to
      # manifests whose `to` is ≤ target.
      def eligible_manifests
        Spree::Upgrade.available_manifests
          .select { |manifest| manifest_eligible?(manifest) }
          .map { |entry| load_manifest_yaml(entry) }
      end

      def manifest_eligible?(manifest)
        if dry_run && !target_explicit
          Spree::Upgrade.compare(manifest[:from], Spree::Upgrade.installed_minor_version) >= 0
        else
          Spree::Upgrade.compare(manifest[:to], target_version) <= 0
        end
      end

      def load_manifest_yaml(entry)
        YAML.safe_load_file(File.join(entry[:dir], 'manifest.yml'))
      end

      def run_full_walk(manifests)
        total_steps = manifests.sum { |m| m['steps'].size }
        reported_target = if dry_run && !target_explicit
                            manifests.map { |m| m['to'] }.compact.max_by { |v| Spree::Upgrade.version_parts(v) } || target_version
                          else
                            target_version
                          end
        puts
        puts "  Walking #{manifests.size} manifest(s), #{total_steps} step(s) total. Target: Spree #{reported_target}."

        manifests.each do |manifest|
          print_manifest_header(manifest)
          manifest['steps'].each_with_index do |step, i|
            print_step(step, i + 1, manifest['steps'].size)
            print_step_complete(step) if !dry_run && invoke(step)
          end
        end

        puts
        puts dry_run ? '  (dry run — nothing executed)' : '  Upgrade tasks complete.'
      end

      # STEP=<id> looks across every eligible manifest; we need exactly one
      # match. Multiple matches are likely a manifest bug (two manifests
      # referencing the same step id) but we surface it rather than picking
      # silently.
      def run_single_step(manifests)
        matches = manifests.flat_map do |manifest|
          manifest['steps'].select { |s| s['id'] == step_id }.map { |s| [manifest, s] }
        end

        if matches.empty?
          available = manifests.flat_map { |m| m['steps'] }.map { |s| s['id'] }.uniq.join(', ')
          abort "  No step with id '#{step_id}' in any eligible manifest. Available: #{available}"
        elsif matches.size > 1
          locations = matches.map { |m, _| "#{m['from']} → #{m['to']}" }.join(', ')
          abort "  Step id '#{step_id}' is ambiguous — defined in: #{locations}. Pass TO=<version> to narrow."
        end

        manifest, step = matches.first
        print_manifest_header(manifest)
        print_step(step, 1, 1)
        print_step_complete(step) if !dry_run && invoke(step)

        puts
        puts dry_run ? '  (dry run — nothing executed)' : "  Step '#{step_id}' complete."
      end

      def print_manifest_header(manifest)
        puts
        puts "  ── Spree #{manifest['from']} → #{manifest['to']} ──"
        puts "  Docs: #{manifest['docs']}" if manifest['docs']
      end

      def print_step(step, index, total)
        puts
        puts "  Step #{index}/#{total} [#{step['id']}]"
        puts "    #{step['name']}"
        puts "    > #{step_command(step)}"
        return unless step['notes']

        step['notes'].each_line { |line| puts "    #{line.chomp}" }
      end

      def print_step_complete(step)
        puts "    ✓ #{step_label(step)} done."
      end

      def step_label(step)
        step['task_class'] || step['task']
      end

      def step_command(step)
        if step['task_class']
          "bin/rake \"spree:maintenance_tasks:perform[#{step['task_class']}]\""
        else
          "bin/rake #{step['task']}"
        end
      end

      # Both step kinds run through the maintenance task runner, so a shell
      # walk records the same audit rows a dashboard run does: a class-backed
      # step runs its own task, a rake-backed step runs inside UpgradeStep.
      #
      # Returns false when the step was skipped, so the caller can leave the
      # "done" line off a step that never ran.
      def invoke(step)
        return false if skip_uninstalled?(step)

        puts "    Running #{step_label(step)}..."

        result = Spree::MaintenanceTasks::Start.call(
          task_name: step['task_class'] || 'Spree::MaintenanceTasks::UpgradeStep',
          arguments: step['task_class'] ? {} : { 'step_id' => step['id'] },
          initiated_via: 'cli',
          inline: true
        )

        abort "    #{result.error}" if result.failure?

        run = result.value.reload
        run.tallies.each { |key, value| puts "      #{key}: #{value}" }

        if run.errored?
          puts "    #{run.error_class}: #{run.error_message}"
          abort '    Step failed. Fix the cause, then re-run this step.'
        end

        true
      end

      # Steps contributed by optional gems (payment gateways, for instance)
      # are absent unless that gem is installed. Skipping keeps the upgrade
      # runnable on installs that never had the gem, while an install that
      # does have it still gets the backfill.
      #
      # The check reads the rake task even for a class-backed step, since an
      # optional step's task class ships in the same absent gem.
      def skip_uninstalled?(step)
        return false unless step['optional']

        if step['task_class']
          return false if Spree::MaintenanceTask.find_registered(step['task_class'])
        elsif Rake::Task.task_defined?(step['task'])
          return false
        end

        puts "    Skipping #{step_label(step)} — not installed."
        true
      end
    end
  end
end
