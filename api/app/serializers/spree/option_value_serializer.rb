module Spree
  class OptionValueSerializer < ActiveModel::Serializer
    attributes :id, :option_type_id, :option_type_name, :name, :presentation
  end
end
