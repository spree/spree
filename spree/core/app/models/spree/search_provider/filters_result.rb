module Spree
  module SearchProvider
    FiltersResult = Struct.new(:filters, :sort_options, :default_sort, :total_count, keyword_init: true)
  end
end
