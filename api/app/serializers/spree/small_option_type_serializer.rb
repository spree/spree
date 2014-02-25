module Spree
  class SmallOptionTypeSerializer < ActiveModel::Serializer
    attributes :id, :name, :position, :presentation
  end
end
