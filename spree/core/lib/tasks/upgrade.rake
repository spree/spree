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

module Spree
  module Upgrade
    # Two-segment "5.5" form of the installed Spree version.
    def self.installed_minor_version
      Spree.version.split('.').first(2).join('.')
    end

    # Root directory containing N_M_to_O_P/manifest.yml files inside
    # the spree_core gem.
    def self.manifests_root
      File.expand_path('../spree/upgrades', __dir__)
    end

    # All available manifest directories, parsed into { from:, to:, dir: }.
    # Sorted by `to` ascending, with `from` as a tiebreaker (smallest first)
    # for the rare case where two manifests share a `to` boundary.
    def self.available_manifests
      Dir.glob(File.join(manifests_root, '*_to_*')).filter_map do |dir|
        name = File.basename(dir)
        match = name.match(/\A([\d_]+)_to_([\d_]+)\z/)
        next unless match

        { from: match[1].tr('_', '.'), to: match[2].tr('_', '.'), dir: dir }
      end.sort_by { |m| version_parts(m[:to]) + version_parts(m[:from]) }
    end

    def self.version_parts(v)
      v.split('.').map { |s| Integer(s, 10) rescue 0 }
    end

    # Compare two dotted-version strings (returns -1, 0, +1).
    def self.compare(a, b)
      version_parts(a) <=> version_parts(b)
    end

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
            unless dry_run
              invoke(step)
              print_step_complete(step)
            end
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
        unless dry_run
          invoke(step)
          print_step_complete(step)
        end

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
        puts "    > bin/rake #{step['task']}"
        return unless step['notes']

        step['notes'].each_line { |line| puts "    #{line.chomp}" }
      end

      def print_step_complete(step)
        puts "    ✓ #{step['task']} done."
      end

      def invoke(step)
        task = step.fetch('task')
        puts "    Running #{task}..."

        # Rake caches invoked tasks in-process; explicit reenable lets a
        # single `rake spree:upgrade` run re-invoke aggregators that share
        # subtasks across multiple manifests (e.g. two manifests both
        # depending on `spree:install:migrations` would otherwise only
        # invoke it once).
        rake_task = Rake::Task[task]
        rake_task.reenable
        rake_task.invoke
      end
    end
  end
end
