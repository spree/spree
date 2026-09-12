module Spree
  module Api
    module V3
      module Admin
        # Per-member authorization for the reporting vocabulary. Metrics,
        # dimensions and counters all declare a `subject` (checked for JWT
        # staff through CanCanCan) paired with a `key_scope` (checked for
        # secret keys), so one predicate answers for every member and every
        # surface that lists them — the schema, a query, the home screen's
        # counters — filters by the same rule.
        module ReportingAuthorization
          extend ActiveSupport::Concern

          private

          def member_allowed?(member)
            if current_api_key.present?
              member.key_scope.blank? || current_api_key.has_scope?(member.key_scope)
            else
              member.subject.nil? || can?(:read, member.subject.call)
            end
          end
        end
      end
    end
  end
end
