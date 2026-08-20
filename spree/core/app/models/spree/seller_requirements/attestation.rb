# frozen_string_literal: true

module Spree
  module SellerRequirements
    # Something the marketplace asks the seller to confirm in their own
    # right — that their delivery rates are correct, that they hold the
    # licence their category needs. The seller ticks it and it is met; the
    # value is the record that they were asked and answered.
    #
    # The question is whatever the operator wrote in the row's name and
    # description, so a store may configure as many as it likes.
    class Attestation < Spree::SellerRequirement
      def self.allow_multiple?
        true
      end

      def self.accepts_submissions?
        true
      end
    end
  end
end
