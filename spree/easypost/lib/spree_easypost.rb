require 'easypost'
require 'spree_core'
require 'spree_easypost/engine'

module SpreeEasyPost
  OUNCES_PER_UNIT = {
    'imperial' => 16.0,   # pounds
    'metric' => 0.03527396 # grams
  }.freeze

  # EasyPost expects parcel weight in ounces; Spree stores weight in the
  # store's unit system.
  #
  # @param weight [Numeric, nil]
  # @param store [Spree::Store, nil]
  # @return [Float]
  def self.ounces(weight, store)
    unit_system = store&.preferred_unit_system.presence || 'imperial'
    (weight.to_f * OUNCES_PER_UNIT.fetch(unit_system.to_s, 16.0)).round(2)
  end
end
