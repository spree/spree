module Spree
  class SmallOptionTypeSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.option_types_attributes
    attributes :id, :name, :position, :presentation
  end
end
