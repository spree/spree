module Spree
  class OptionTypeSerializer < ActiveModel::Serializer
    # attributes *Spree::Api::ApiHelpers.option_type_attributes
    attributes :id, :name, :position, :presentation

    has_many :option_values
  end
end
