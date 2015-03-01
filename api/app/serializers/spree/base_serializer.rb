module Spree
  class BaseSerializer < ActiveModel::Serializer
    cached
    delegate :cache_key, to: :object
  end
end
