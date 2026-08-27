# frozen_string_literal: true

module Spree
  module SellerRequirements
    # The seller has published one named legal document — a returns policy, a
    # shipping policy, whatever this marketplace asks for.
    #
    # One row per document rather than a list on a single row: a marketplace
    # asking for two policies is asking two things, and a seller who has
    # written one of them should see that line go green rather than a single
    # line that stays blocked. It also means the operator names the document
    # in the row's own `name` — which `allow_multiple?` already requires — so
    # there is no second vocabulary to keep in step with it.
    #
    # The seller's policy matches on that name, case- and whitespace-
    # insensitively, and must actually have something written in it.
    class Policy < Spree::SellerRequirement
      # The row's name IS the document required, so a marketplace adds this
      # kind once per policy it asks for.
      def self.allow_multiple?
        true
      end

      def met_by_seller?(seller)
        required = required_policy_name
        return true if required.blank?

        seller.policies.any? do |policy|
          policy.name.to_s.strip.casecmp?(required) && policy.with_body?
        end
      end

      # The document this row asks for: the operator's own wording, which the
      # seller panel pre-fills when creating the policy so the two match by
      # construction.
      #
      # @return [String]
      def required_policy_name
        display_name.to_s.strip
      end
    end
  end
end
