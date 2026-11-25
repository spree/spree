module Spree
  module Api
    module V3
      module Admin
        # How many products a category, collection, price list or catalog
        # gained or lost. Products it already held, or never held, are not counted.
        class ProductMembershipResultSerializer
          include Alba::Resource
          include Typelizer::DSL

          %i[added_count removed_count].each do |name|
            typelize name => [:number, optional: true, comment: "Sent when products were #{name == :added_count ? 'added' : 'removed'}"]
            attribute(name, if: proc { |result| result.key?(name) }) { |result| result[name] }
          end
        end
      end
    end
  end
end
