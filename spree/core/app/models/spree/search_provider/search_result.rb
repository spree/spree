module Spree
  module SearchProvider
    SearchResult = Struct.new(:products, :total_count, :pagy, keyword_init: true)
  end
end
