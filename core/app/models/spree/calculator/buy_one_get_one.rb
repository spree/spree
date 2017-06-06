module Spree
  class Calculator::BuyOneGetOne < ActiveRecord::Base    
	attr_accessible :preferred_number_to_buy, :preferred_number_to_get
	preference :number_to_buy, :integer, :default => 1
	preference :number_to_get, :integer, :default => 1
 
	def self.description
		Spree.t(:buy_x_get_y)		
	end
	 
	def compute(order)
		line_items = applicable_line_items(order)
		 
		prices = prices_from_line_items(line_items).sort
		 
		amount = prices.first(number_free(prices.size)).sum
		 
		amount == 0 ? nil : amount
	end
	 
	private
	 
		def free_ratio
			self.preferred_number_to_get.to_f / ( self.preferred_number_to_get + self.preferred_number_to_buy )
		end
		 
		def applicable_line_items(order)
			order.line_items.select{|li| li.product.respond_to?(:is_gift_card?) ? (not li.product.is_gift_card?) : true }
		end
		 
		def prices_from_line_items(line_items)
			line_items.inject([]) {|prices, li| prices.concat [li.price]*li.quantity }
		end
		 
		def number_free(number_of_items)
			(number_of_items * free_ratio).to_i
		end
  end
end
