# frozen_string_literal: true

module Spree
  module SellerRequirements
    # The seller has accepted the marketplace's terms.
    #
    # `terms_effective_from` is how a marketplace asks again after rewriting
    # them: everyone who accepted before that date falls back to unmet, and
    # the seller sees the requirement return to their checklist.
    class AcceptTerms < Spree::SellerRequirement
      preference :terms_effective_from, :string, default: nil
      # Where the terms actually are. A URL rather than stored copy: a
      # marketplace already publishes its terms somewhere, and keeping a
      # second copy here would be the one that goes stale. Optional — a
      # marketplace that agrees terms out of band still uses this kind to
      # record that the seller accepted.
      preference :terms_url, :string, default: nil

      # A date nobody can parse would otherwise read as "no date at all", and
      # this requirement would quietly count sellers on years-old terms as
      # having accepted the current ones. Refused on save so it cannot be
      # stored, rather than interpreted generously afterwards.
      validate :terms_effective_from_must_be_a_date

      def met_by_seller?(seller)
        accepted_at = seller.terms_accepted_at
        return false if accepted_at.blank?
        return true if effective_from.blank?

        accepted_at >= effective_from
      end

      # `iso8601`, not `parse`: parse fills in whatever a value leaves out, so
      # "09:00" becomes nine o'clock *today* and the threshold would move every
      # midnight — sellers who met it yesterday would fall out of compliance
      # overnight. A cut-off has to be a fixed instant.
      #
      # Read in the store's timezone, not the server's: a date the operator
      # types means midnight where they trade, and interpreting "2026-01-01"
      # in UTC would move the deadline by hours for everyone else.
      #
      # The terms themselves, so the seller can read what they are accepting.
      # `action_url` is the checklist's existing "go here" channel, which the
      # panel already renders — no new field for one kind.
      #
      # @return [String, nil]
      def action_url(_seller)
        preferred_terms_url.presence
      end

      # @return [ActiveSupport::TimeWithZone, nil]
      def effective_from
        return nil if preferred_terms_effective_from.blank?

        # `find_zone` answers nil for a zone it does not know, so a store
        # carrying a bad value falls back rather than raising here.
        zone = Time.find_zone(store&.preferred_timezone.to_s) || Time.zone

        zone.iso8601(preferred_terms_effective_from.to_s)
      rescue ArgumentError, Date::Error
        nil
      end

      private

      def terms_effective_from_must_be_a_date
        return if preferred_terms_effective_from.blank?
        return if effective_from.present?

        errors.add(:base, Spree.t('seller_requirements.invalid_terms_effective_from',
                                  default: 'Terms effective from is not a date'))
      end
    end
  end
end
