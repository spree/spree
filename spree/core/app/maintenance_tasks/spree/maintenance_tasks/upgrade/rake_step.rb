module Spree
  module MaintenanceTasks
    module Upgrade
      # Base for the 5.6 → 6.0 steps whose work is a single set-based pass:
      # a handful of UPDATEs that finish in seconds and have nothing to
      # checkpoint (docs/plans/6.0-maintenance-tasks.md).
      #
      # These keep their rake body as the implementation rather than being
      # rewritten. The bodies are covered by a spec suite that invokes them by
      # task name, and reimplementing set-based SQL as a row walk would trade
      # tested code for a progress bar on work that has no rows to report.
      # What they gain here is the run row: who ran the step, when, and what it
      # reported.
      #
      # Steps that genuinely walk rows are collection tasks in their own right
      # — see `Upgrade::CaptureMethods` and its siblings.
      class RakeStep < Spree::MaintenanceTask
        no_collection

        class_attribute :rake_task_name, instance_writer: false
        class_attribute :environment_parameters, instance_writer: false, default: {}.freeze

        # @param name [String] the rake task this step runs
        def self.runs_rake_task(name)
          self.rake_task_name = name
        end

        # Declares a parameter the rake body reads from the environment.
        #
        # These bodies were written for a shell, so their answers arrive as
        # environment variables. Mapping them to attributes is what lets the
        # dashboard ask the question — "was a Devise pepper ever set?" — instead
        # of failing with an instruction to re-run with a variable exported.
        #
        # @param attribute_name [Symbol]
        # @param as [String] the environment variable the body reads
        def self.passes_to_environment(attribute_name, as:)
          self.environment_parameters = environment_parameters.merge(attribute_name.to_sym => as).freeze
        end

        def process
          load_engine_rake_tasks

          with_environment do
            task = ::Rake::Task[self.class.rake_task_name]
            task.reenable
            task.invoke
          end

          tally(:completed)
        end

        private

        # Restored afterwards so one run never leaks its answers into the next.
        def with_environment
          return yield if self.class.environment_parameters.empty?

          keys = self.class.environment_parameters.values
          previous = ENV.to_h.slice(*keys)

          self.class.environment_parameters.each do |attribute_name, variable|
            ENV[variable] = environment_value(public_send(attribute_name))
          end

          yield
        ensure
          keys&.each { |key| ENV[key] = previous[key] }
        end

        def environment_value(value)
          case value
          when true then 'true'
          when false, nil then nil
          else value.to_s.presence
          end
        end

      end
    end
  end
end
