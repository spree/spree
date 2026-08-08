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
      attribute :estimated_delivery_date, :date
      attribute :metadata, default: -> { {} }
    end
  end
end
