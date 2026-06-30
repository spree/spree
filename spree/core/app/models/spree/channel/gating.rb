module Spree
  class Channel
    # Storefront access gating for a channel. Decides what an anonymous
    # (not-logged-in) visitor may see and whether an order may be placed
    # without an account. Both controls fall back to the owning Store when the
    # channel preference is unset, mirroring +OrderRouting::HasStrategyPreference+.
    module Gating
      extend ActiveSupport::Concern

      # Posture controlling catalog/price visibility for anonymous visitors:
      # - +public+         products + prices visible to anyone
      # - +prices_hidden+  products browsable, prices null for guests
      # - +login_required+ catalog reads rejected for guests
      STOREFRONT_ACCESS = %w[public prices_hidden login_required].freeze

      included do
        # Empty -> falls back to the Store-level preference.
        preference :storefront_access, :string, default: nil
        preference :guest_checkout, :boolean, default: nil

        validate :storefront_access_must_be_valid
      end

      # @return [String] the effective access posture: the channel preference,
      #   or the store fallback when unset, defaulting to +public+.
      def resolved_storefront_access
        preferred_storefront_access.presence ||
          store&.preferred_storefront_access.presence ||
          'public'
      end

      # @return [Boolean] whether guest checkout is allowed: the channel
      #   preference, or the store fallback when the channel value is unset.
      def resolved_guest_checkout
        value = preferred_guest_checkout
        return value unless value.nil?

        store.nil? ? true : store.preferred_guest_checkout
      end

      # @return [Boolean] true when guests must not see prices on this channel.
      def storefront_prices_hidden?
        resolved_storefront_access == 'prices_hidden'
      end

      # @return [Boolean] true when guests must authenticate before browsing.
      def storefront_login_required?
        resolved_storefront_access == 'login_required'
      end

      private

      def storefront_access_must_be_valid
        value = preferred_storefront_access
        return if value.blank?
        return if STOREFRONT_ACCESS.include?(value.to_s)

        errors.add(
          :preferred_storefront_access,
          Spree.t(:invalid_storefront_access, scope: [:errors, :messages], default: 'is not a valid storefront access level')
        )
      end
    end
  end
end
