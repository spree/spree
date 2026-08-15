module Spree
  # Ephemeral value object returned by PickupPointProvider queries. Never
  # persisted — the selected option is frozen into
  # +fulfillment.pickup_point_data+ as plain JSON.
  class PickupPointOption
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :external_id, :string
    attribute :name, :string
    attribute :address1, :string
    attribute :address2, :string
    attribute :city, :string
    attribute :zipcode, :string
    attribute :country_code, :string
    attribute :latitude, :float
    attribute :longitude, :float
    attribute :provider, :string
    attribute :metadata

    validates :external_id, :name, presence: true

    # @return [Hash] the JSON shape persisted into fulfillment.pickup_point_data
    def to_pickup_point_data
      attributes.compact.stringify_keys
    end
  end
end
