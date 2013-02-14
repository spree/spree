module Spree
  module Stock
    module Splitter
      class Base
        attr_accessor :stock_location, :order, :next_splitter

        def initialize(packer, next_splitter=nil)
          @stock_location = packer.stock_location
          @order = packer.order
          @next_splitter = next_splitter
        end

        def split(packages)
          return_next(packages)
        end

        private
        def return_next(packages)
          next_splitter ? next_splitter.split(packages) : packages
        end
      end

      class ShippingCategory < Base
        def split(packages)
          #TODO regroup items by shipping category
          return_next(packages)
        end
      end
    end
  end
end
