module Spree
  class OptionTypeSerializer < ActiveModel::Serializer
    attributes :id, :name, :position, :presentation

    has_many :option_values
  end
end
