module Spree
  class Variant < Spree::Base
    scope :descend_by_popularity, -> {
      ActiveSupport::Deprecation.warn "Variant.descend_by_popularity is deprecated and will be removed from Spree 3.", caller
      order("COALESCE((SELECT COUNT(*) FROM  #{LineItem.quoted_table_name} GROUP BY #{LineItem.quoted_table_name}.variant_id HAVING #{LineItem.quoted_table_name}.variant_id = #{Variant.quoted_table_name}.id), 0) DESC")
    }

    class << self
      # Returns variants that match a given option value
      #
      # Example:
      #
      # product.variants_including_master.has_option(OptionType.find_by(name: 'shoe-size'), OptionValue.find_by(name: '8'))
      def has_option(option_type, *option_values)
        ActiveSupport::Deprecation.warn "Variant.descend_by_popularity is deprecated and will be removed from Spree 3.", caller
        option_types = OptionType.table_name

        option_type_conditions = case option_type
        when OptionType then { "#{option_types}.name" => option_type.name }
        when String     then { "#{option_types}.name" => option_type }
        else                 { "#{option_types}.id"   => option_type }
        end

        relation = joins(:option_values => :option_type).where(option_type_conditions)

        option_values_conditions = option_values.each do |option_value|
          option_value_conditions = case option_value
          when OptionValue then { "#{OptionValue.table_name}.name" => option_value.name }
          when String      then { "#{OptionValue.table_name}.name" => option_value }
          else                  { "#{OptionValue.table_name}.id"   => option_value }
          end
          relation = relation.where(option_value_conditions)
        end

        relation
      end

      alias_method :has_options, :has_option
    end
  end
end
