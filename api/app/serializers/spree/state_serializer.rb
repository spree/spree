module Spree
  class StateSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.state_attributes
    attributes :id, :name, :abbr, :country_id
  end
end
