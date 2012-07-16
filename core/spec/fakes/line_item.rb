require 'fakes/model'

module Spree
  class LineItem
    include FakeModel
    attr_accessor :variant, :variant_id, :price, :quantity, :adjustments

    def initialize(attributes={})
      attributes.each do |key, value|
        self.send("#{key}=", value)
      end
    end

    def adjustments
      @adjustments ||= []
    end
  end
end
