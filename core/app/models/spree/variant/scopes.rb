module Spree
  class Variant < ActiveRecord::Base
    #FIXME WARNING tested only under sqlite and postgresql
    scope :descend_by_popularity, order("COALESCE((SELECT COUNT(*) FROM  #{Spree::LineItem.quoted_table_name} GROUP BY #{Spree::LineItem.quoted_table_name}.variant_id HAVING #{Spree::LineItem.quoted_table_name}.variant_id = #{Spree::Variant.quoted_table_name}.id), 0) DESC")
  end

end

# for selecting variants with an option value
# no option type given since the value implies an option type
# this scope can be chained repeatedly, since the join name is unique
Spree::Variant.scope :has_option, lambda {|opt|
  tbl = 'o' + Time.now.to_i.to_s + Time.now.usec.to_s
  { :joins => "inner join spree_option_values_variants as #{tbl} on #{Spree::Variant.quoted_table_name}.id = #{tbl}.variant_id",
    :conditions => ["#{tbl}.option_value_id = (?)", opt]
  }
}
