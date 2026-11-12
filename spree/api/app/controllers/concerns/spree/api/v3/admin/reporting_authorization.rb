module Spree
  module Api
    module V3
      module Admin
        # Per-member authorization for the reporting vocabulary. Metrics,
        # dimensions and counters all declare a `key_scope` paired with a
        # `subject`, so one predicate answers for every member and every
        # surface that lists them — the schema, a query, the home screen's
        # counters — filters by the same rule.
        #
        # Asked of the credential rather than of its owner. Branching on
        # `current_api_key` measured an OAuth grant against the approving
        # staff member's whole role, because a token authenticates as that
        # person and carries no key: a grant for `read_reports` alone could
        # group a report by customer and read names, emails and spend.
        # `holds_permission?` is the narrowed answer for all three
        # principals — a key's scopes, a grant's, or the role when someone is
        # acting directly at the dashboard.
        module ReportingAuthorization
          extend ActiveSupport::Concern

          private

          def member_allowed?(member)
            return false unless member.key_scope.blank? || holds_permission?(member.key_scope)

            # The permission says whether this kind of data is in scope at
            # all; a host app's record-level rule can still narrow which of
            # it this person sees.
            member.subject.nil? || can?(:read, member.subject.call)
          end
        end
      end
    end
  end
end
