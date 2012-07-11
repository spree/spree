require 'support/fake_model'

module Spree
  class LineItem < FakeModel
    attr_accessor :variant, :variant_id, :price, :quantity

    def initialize(attributes={})
      attributes.each do |key, value|
        self.send("#{key}=", value)
      end
    end
  end
end
