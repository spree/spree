module Spree
  class ShipmentTransition < ActiveRecord::Base
    include Statesman::Adapters::ActiveRecordTransition

    belongs_to :shipment, class_name: 'Spree::Shipment', inverse_of: :shipment_transitions
  end
end
