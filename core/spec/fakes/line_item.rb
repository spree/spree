require 'fakes/model'

module Spree
  class LineItem
    include FakeModel
    attr_accessor :variant, :variant_id, :price, :quantity

    def initialize(attributes={})
      attributes.each do |key, value|
        self.send("#{key}=", value)
      end
    end
  end
end
