module Spree
  module Adjustable
    module Adjuster
      class Base
        def self.adjust(adjustable, totals)
          new(adjustable, totals).update
        end

        def initialize(adjustable, totals)
          @adjustable = adjustable
          @totals = totals
        end

        def update
          raise NotImplementedError, "Please implement 'update' in your adjuster: #{self.class.name}"
        end

        private

        attr_reader :adjustable
        delegate :adjustments, to: :adjustable
      end
    end
  end
end
