# frozen_string_literal: true

module Spree
  module SellerRequirements
    # Something a person at the marketplace checks by hand — a tax number
    # against a public register, a trading history elsewhere. The seller says
    # they are ready and gives whatever reference the operator asked for; the
    # requirement is met when someone accepts it.
    class OperatorReview < Spree::SellerRequirement
      def self.allow_multiple?
        true
      end

      def self.accepts_submissions?
        true
      end

      def self.reviewed_by_operator?
        true
      end
    end
  end
end
