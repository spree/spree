module Spree
  module MaintenanceTasks
    module Upgrade
      # Base for the one-pass upgrade steps that ask the operator for parameters
      # (docs/plans/6.0-maintenance-tasks.md). The rake body stays the
      # implementation; this class only maps its parameters onto the environment
      # variables the body reads. A step without parameters runs through
      # `UpgradeStep` and needs no class at all.
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
          with_environment { invoke_rake_task(self.class.rake_task_name) }

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
