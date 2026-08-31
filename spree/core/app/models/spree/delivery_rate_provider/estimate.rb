module Spree
  module DeliveryRateProvider
    # A single quote returned by a delivery rate provider.
    #
    # +cost+ is pre-tax and pre-VAT-gross-up: the Estimator applies
    # +gross_amount+ and resolves the tax rate afterwards, exactly as it does
    # for calculator output. Everything else is carrier metadata that flows
    # onto the persisted DeliveryRate.
    class Estimate
      include ActiveModel::Model
      include ActiveModel::Attributes

      attribute :cost, :decimal
      # True when the price is not known yet and will be quoted separately —
      # freight a forwarder rates after the merchant reviews the order. The
      # estimator skips markup and tax for these, and display surfaces say so
      # rather than showing the zero cost as free shipping.
      attribute :unpriced, :boolean, default: false
      # ISO code of the currency the provider quoted in. Nil means the
      # store's own currency (Internal); carrier quotes come back in the
      # carrier account's currency and are dropped when it differs from the
      # cart's — a number in the wrong currency must never reach checkout.
      attribute :currency, :string
      attribute :carrier, :string
      attribute :service_level, :string
      # Optional display name; when blank the Estimator derives one from
      # carrier + service_level (or falls back to the method name).
      attribute :name, :string
      attribute :estimated_delivery_date, :date
      attribute :metadata, default: -> { {} }

      # Stable identity of the carrier service within a method — what
      # DeliveryMethodService rows match against for selection filtering and
      # label/markup overrides.
      #
      # @return [String, nil]
      def service_key
        return if carrier.blank? && service_level.blank?

        [carrier, service_level].compact.join('/')
      end
    end
  end
end
