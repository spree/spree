module Spree
  class PropertySerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.property_attributes
    attributes :id, :name, :presentation
  end
end
