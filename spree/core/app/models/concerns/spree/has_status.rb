module Spree
  # Declarative status column for models whose transitions belong to workflows
  # rather than a state machine (docs/plans/6.0-service-workflows.md,
  # decision 11).
  #
  #   class Spree::Return < Spree.base_class
  #     include Spree::HasStatus
  #     has_status :requested, :approved, :received, :refunded, :canceled,
  #                default: :requested
  #   end
  #
  # Generates an inclusion validation, a predicate per value (`#received?`)
  # and a scope per value (`.received`) — nothing else. There are no events,
  # no transition graph and no callbacks: moving a record between statuses is
  # a workflow's job, which is what lets a transition take arguments, perform
  # gateway I/O outside a transaction, and compensate when a later step fails.
  #
  # Values live in a class_attribute rather than a frozen constant so an
  # extension can add its own without reopening core.
  module HasStatus
    extend ActiveSupport::Concern

    class_methods do
      # @param values [Array<Symbol, String>] the valid statuses, in order
      # @param default [Symbol, String] applied by the creating workflow —
      #   never a database default (see the migration rules in CLAUDE.md)
      def has_status(*values, default:)
        values = values.map(&:to_s)

        class_attribute :statuses, default: values, instance_writer: false
        class_attribute :default_status, default: default.to_s, instance_writer: false

        validates :status, inclusion: { in: ->(record) { record.class.statuses } }

        values.each { |value| define_status_methods(value) }
      end

      # Appends a status. Additive by design: core workflows guard on core
      # statuses (`Returns::Refund` requires `received?`), so allowing removal
      # would silently break those guards — they would simply never pass.
      #
      # A custom status needs a custom workflow to move records into it. That
      # is deliberate rather than a gap: validating transitions centrally
      # would be a state machine by another name.
      #
      # @param value [Symbol, String]
      # @param after [Symbol, String, nil] position in the list; appended when nil
      def add_status(value, after: nil)
        value = value.to_s
        return if statuses.include?(value)

        index = after ? statuses.index(after.to_s)&.succ : nil
        self.statuses = statuses.dup.insert(index || statuses.size, value)
        define_status_methods(value)
      end

      private

      def define_status_methods(value)
        define_method(:"#{value}?") { status == value }
        scope value, -> { where(status: value) }
      end
    end
  end
end
