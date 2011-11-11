module Spree
  class Variant < ActiveRecord::Base
    #FIXME WARNING tested only under sqlite and postgresql
    scope :descend_by_popularity, order("COALESCE((SELECT COUNT(*) FROM  #{Spree::LineItem.quoted_table_name} GROUP BY #{Spree::LineItem.quoted_table_name}.variant_id HAVING #{Spree::LineItem.quoted_table_name}.variant_id = #{Spree::Variant.quoted_table_name}.id), 0) DESC")


    class << self
      # Returns variants that match a given option value
      #
      # Example:
      #
      # product.variants_including_master.has_option(OptionType.find_by_name("shoe-size"),OptionValue.find_by_name("8"))
      def has_option(option_type, *options)
        joins(:option_values => :option_type).where("spree_option_types.name = ? AND spree_option_values.id IN (?)", option_type.name, options.map(&:id))
      end

      alias_method :has_options, :has_option
    end
  end

end
