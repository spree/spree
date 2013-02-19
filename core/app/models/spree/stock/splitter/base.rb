module Spree
  module Stock
    module Splitter
      class Base
        attr_reader :packer, :next_splitter

        def initialize(packer, next_splitter=nil)
          @packer = packer
          @next_splitter = next_splitter
        end
        delegate :stock_location, :order, :to => :packer

        def split(packages)
          return_next(packages)
        end

        private
        def return_next(packages)
          next_splitter ? next_splitter.split(packages) : packages
        end
      end
    end
  end
end
