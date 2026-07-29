module Spree
  # Ephemeral value object returned by PickupPointProvider queries. Never
  # persisted — the selected option is frozen into
  # +fulfillment.pickup_point_data+ as plain JSON.
  PickupPointOption = Struct.new(
    :external_id,
    :name,
    :address1,
    :address2,
    :city,
    :zipcode,
    :country_iso,
    :latitude,
    :longitude,
    :provider,
    :metadata,
    keyword_init: true
  ) do
    def to_pickup_point_data
      to_h.compact.stringify_keys
    end
  end
end
