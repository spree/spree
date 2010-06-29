module Spree::Search
  class Base
    attr_accessor :properties

    def initialize
      @properties = {}
    end

    # method should return hash with conditions {:conditions=> "..."} for Product model
    def get_products_conditions_for(query)
      query = query.split
      Product.name_or_description_like_any(query).scope(:find)
    end

    def prepare(params)
    end

    def method_missing(name)
      @properties[name]
    end
  end
end
