# frozen_string_literal: true

module Spree
  module SellerRequirements
    # The seller has published the legal documents this marketplace asks of
    # them — a returns policy, a shipping policy, whatever the operator names.
    #
    # Configured with policy names rather than ids: a seller's policy is their
    # own row, so there is no shared record to point at, and the seller panel
    # creates missing ones pre-filled with the required name, which is what
    # keeps the two sides matching. Matching is case-insensitive and goes
    # through the translated name, so a seller writing in their own locale
    # still satisfies it.
    class Policy < Spree::SellerRequirement
      preference :required_policies, :array, default: [], parse_on_set: lambda { |values|
        Array(values).map { |value| value.to_s.strip }.compact_blank.uniq
      }

      def met_by_seller?(seller)
        missing_policies_for(seller).empty?
      end

      # Which of the required documents the seller still owes — the names,
      # in the order the operator listed them.
      #
      # Drives both the answer above and what the onboarding card shows, so a
      # seller is told which document is missing rather than that something is.
      #
      # @param seller [Spree::Seller]
      # @return [Array<String>]
      def missing_policies_for(seller)
        return [] if preferred_required_policies.blank?

        published = seller.policies.select(&:with_body?)

        # Both sides are trimmed at compare time, not just on write: the
        # preference writer normalizes, but the reader hands back whatever is
        # stored, so a row written by any path that skips the setter would
        # otherwise hold a name no seller could ever match.
        preferred_required_policies.reject do |name|
          required = name.to_s.strip
          published.any? { |policy| policy.name.to_s.strip.casecmp?(required) }
        end
      end
    end
  end
end
