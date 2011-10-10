module Spree
  module Scopes
    # This module is extended by ProductScope
    module Dynamic
      module_function

      # Sample dynamic scope generating from set of products
      # generates 0 or (2..scope_limit) scopes for prices, based
      # on number of products (uses Math.log, to guess number of scopes)
      def price_scopes_for(products, scope_limit=5)
        scopes = []

        # Price based scopes
        all_prices = products.map(&:price).sort

        ranges = [Math.log(products.length).floor, scope_limit].max

        if ranges >= 2
          l = all_prices.length / ranges
          scopes << ProductScope.new({:name => "master_price_lte", :arguments => [all_prices[l]] })

          (ranges - 2).times do |x|
            scopes << ProductScope.new({:name => "price_between",
                                        :arguments => [ all_prices[l*(x+1)+1], all_prices[l*(x+2)] ] })
          end
          scopes << ProductScope.new({:name => "master_price_gte", :arguments => [all_prices[l*(ranges-1)+1]] })
        end

        scopes
      end
    end
  end
end
