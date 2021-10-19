require 'pry'

module RuboCop
  module Cop
    module Spree
      module Migration
        # This cop looks for the argument used when invoking Migration.[].
        # It registers an offense when the version is other than the one
        # defined in the cop configuration or the hardcoded default (5.2).
        #
        # @example
        #   # bad
        #   class AddDeletedAtToSpreeStores < ActiveRecord::Migration
        #   end
        #
        #   class AddDeletedAtToSpreeStores < ActiveRecord::Migration[]
        #   end
        #
        #   class AddDeletedAtToSpreeStores < ActiveRecord::Migration[6.1]
        #   end
        #
        #   class AddDeletedAtToSpreeStores < ActiveRecord::Migration[4.2]
        #   end
        #
        #
        #   # good
        #   class AddDeletedAtToSpreeStores < ActiveRecord::Migration[5.2]
        #   end
        #
        class Version < RuboCop::Cop::Base
          extend AutoCorrector

          def_node_matcher :migration_without_version?, <<~PATTERN
            (class
              (const nil? _)
              $(const
                (const nil? :ActiveRecord) :Migration) _)
          PATTERN
          def_node_matcher :migration_with_empty_version?, <<~PATTERN
            (class
              (const nil? _)
              $(send
                (const
                  (const nil? :ActiveRecord) :Migration) :[]) _)
          PATTERN
          def_node_matcher :unexpected_migration_version?, <<~PATTERN
            (class
              (const nil? _)
              (send
                (const
                  (const nil? :ActiveRecord) :Migration) :[]
                $({float | int} _))
              _)
          PATTERN

          def on_class(node)
            no_version_offense(offense: :migration_without_version?, node: node)
            no_version_offense(offense: :migration_with_empty_version?, node: node)

            unexpected_migration_version?(node) do |current_version|
              next if current_version.value.to_s == expected_rails_version

              expression = current_version.loc.expression
              add_offense(
                expression,
                message: format(
                  UNEXPECTED_MIGRATION_VERSION,
                  current_version: current_version.value,
                  expected_version: expected_rails_version
                )
              ) do |corrector|
                corrector.replace(expression, expected_rails_version)
              end
            end
          end

          private

          MIN_SUPPORTED_VERSION = '5.2'
          NO_MIGRATION_VERSION =
            "Append [%<expected_version>s] to ActiveRecord::Migration.".freeze
          UNEXPECTED_MIGRATION_VERSION =
            "Replace `%<current_version>s` with `%<expected_version>s`.".freeze
          private_constant :MIN_SUPPORTED_VERSION, :NO_MIGRATION_VERSION,
            :UNEXPECTED_MIGRATION_VERSION

          def no_version_offense(offense:, node:)
            send(offense, node) do |capture|
              add_offense(
                node,
                message: format(
                  NO_MIGRATION_VERSION,
                  expected_version: expected_rails_version
                )
              ) do |corrector|
                corrector.replace(
                  capture.loc.expression,
                  "ActiveRecord::Migration[#{expected_rails_version}]"
                )
              end
            end 
          end

          def expected_rails_version
            (cop_config['RailsVersion'] || MIN_SUPPORTED_VERSION).to_s
          end
        end
      end
    end
  end
end
