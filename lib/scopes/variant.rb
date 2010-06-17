module Scopes::Variant
  # WARNING tested only under sqlite and postgresql
  Variant.scope :descend_by_popularity, lambda{
      order('COALESCE((SELECT COUNT(*) FROM  line_items GROUP BY line_items.variant_id HAVING line_items.variant_id = variants.id), 0) DESC')
  }

  # for selecting variants with an option value 
  # no option type given since the value implies an option type
  # this scope can be chained repeatedly, since the join name is unique
  Variant.scope :has_option, lambda {|opt|
    tbl = 'o' + Time.now.to_i.to_s + Time.now.usec.to_s
    { :joins => "inner join option_values_variants as #{tbl} on variants.id = #{tbl}.variant_id",
      :conditions => ["#{tbl}.option_value_id = (?)", opt]
    }
  }
  
end
