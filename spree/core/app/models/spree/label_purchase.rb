module Spree
  # What a label-generating fulfillment provider hands back from
  # +purchase_label+: the carrier's answer, typed, before core turns it into
  # a +Spree::ShippingLabel+ and its +Spree::Delivery+. Ephemeral, never
  # persisted.
  #
  # +cost+ and +currency+ are what the merchant paid the carrier; +file_url+
  # is the provider's hosted copy of the label, fetched into private storage
  # right after purchase. +metadata+ carries whatever ids the provider needs
  # to find the purchase again (a tracker id, a shipment id).
  class LabelPurchase
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :external_id, :string
    attribute :carrier, :string
    attribute :service, :string
    attribute :tracking_number, :string
    attribute :tracking_url, :string
    attribute :cost, :decimal, default: 0
    attribute :currency, :string
    attribute :format, :string
    attribute :file_url, :string
    attribute :metadata, default: -> { {} }

    validates :tracking_number, presence: true
    validates :cost, numericality: { greater_than_or_equal_to: 0 }
  end
end
