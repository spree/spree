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
