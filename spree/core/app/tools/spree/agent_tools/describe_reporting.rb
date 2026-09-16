module Spree
  module AgentTools
    # Tells the model which metrics and dimensions this store can be asked
    # about, so it composes a query from the real vocabulary rather than
    # guessing names and reading errors back to the merchant.
    class DescribeReporting < Spree::AgentTool
      tool_name 'describe_reporting'
      description 'List the reporting metrics and dimensions available, and which dimensions ' \
                  'each metric can be grouped by. Call this before query_report.'
      permission 'read_reports'

      def call
        Spree::Reporting::Schema.new(
          store: context.store,
          allowed: ->(member) { allowed?(member) }
        ).to_h
      end

      def summary(_arguments)
        'List the reporting metrics and dimensions'
      end

      private

      # Filtered to what this caller may reference, so the model is never
      # offered a member its next query would be refused for. The same
      # predicate the reporting schema endpoint applies, in the same two
      # flavours: a subject through CanCanCan for an admin, a key scope for a
      # secret key.
      def allowed?(member)
        if context.user_principal?
          member.subject.nil? || context.can?(:read, member.subject.call)
        else
          context.holds?(member.key_scope)
        end
      end
    end
  end
end
