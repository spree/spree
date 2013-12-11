module Spree
  class OptionValue < ActiveRecord::Base
    belongs_to :option_type, :class_name => 'Spree::OptionType', :touch => true
    acts_as_list scope: :option_type
    has_and_belongs_to_many :variants, join_table: 'spree_option_values_variants', class_name: "Spree::Variant"

    validates :name, :presentation, presence: true

    after_touch :touch_all_variants

    def touch_all_variants
      # This can cause a cascade of products to be updated
      # To disable it in Rails 4.1, we can do this:
      # https://github.com/rails/rails/pull/12772
      # Spree::Product.no_touching do
        variants.find_each(&:touch)
      # end
    end
  end
end
