module Spree
  module Api
    module V3
      module Admin
        # Serializes Spree::CommissionRule — one targeting clause on a rate.
        #
        # Admin-only, like everything commission: what a marketplace charges is
        # between it and its sellers, so there is no Store API counterpart.
        #
        # `subject_name` saves the SPA a lookup per rule: a rules list has to
        # render "Cameras" rather than a prefixed id, and the alternative is
        # three more requests to resolve a handful of names.
        class CommissionRuleSerializer < V3::BaseSerializer
          typelize commission_rate_id: :string,
                   subject_type: 'string | null',
                   subject_id: 'string | null',
                   subject_name: 'string | null'

          attributes :subject_type, created_at: :iso8601, updated_at: :iso8601

          attribute :commission_rate_id do |rule|
            rule.commission_rate&.prefixed_id
          end

          attribute :subject_id do |rule|
            rule.subject&.prefixed_id
          end

          attribute :subject_name do |rule|
            subject = rule.subject
            next nil if subject.nil?

            subject.try(:name) || subject.try(:title)
          end
        end
      end
    end
  end
end
