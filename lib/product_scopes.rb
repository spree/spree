module ProductScopes

  Product.named_scope :price_between, lambda {|low,high| 
    { :joins => :master, :conditions => ["price BETWEEN ? AND ?", low, high] }
  }

  Product.named_scope :taxons_id_in_tree, lambda {|taxon| 
    Product.taxons_id_in_tree_any(taxon).scope :find 
  }

  # TODO - speed test on nest vs join
  Product.named_scope :taxons_id_in_tree_any, lambda {|*taxons| 
    taxons = [taxons].flatten
    { :conditions => [ "products.id in (select product_id from products_taxons where taxon_id in (?))", 
                       taxons.map    {|i| i.is_a?(Taxon) ? i : Taxon.find(i)}.
                              reject {|t| t.nil?}.
                              map    {|t| [t] + t.descendents}.flatten ]}
  }

  # a simple test for product with a certain property-value pairing
  # it can't test for NULLs and can't be cascaded - see :with_property 
  Product.named_scope :with_property_value, lambda { |property, value| 
    Product.product_properties_property_id_equals(property).
            product_properties_value_equals(value).
            scope :find
  }   # coded this way to demonstrate composition


  # a scope which sets up later testing on the values of a given property
  # it takes * a property (object or id), and 
  #          * an optional distinguishing name to support multiple property tests 
  # this version includes results for which the property is not given (ie is NULL),
  #   eg an unspecified colour would come out as a NULL.
  # it probably won't be used without taxon or other filters having narrowed the set 
  #   to a point where results aren't swamped by nulls, hence no inner join version
  Product.named_scope :with_property,
    lambda {|property,*args|
      name = args.empty? ? "product_properties" : args.first
      property_id = case property
                      when Property then property.id 
                      when Fixnum   then property
                    end
      return {} if property_id.nil?
      { :joins => "left outer join product_properties #{name} on products.id = #{name}.product_id and #{name}.property_id = #{property_id}"}
    }
                     

  # add in option_values_variants to the query
  # this is the common info required for all options searches
  Product.named_scope :with_variant_options,
    Product.
      scoped(:joins => :variants).
      scoped(:joins => "join option_values_variants on variants.id = option_values_variants.variant_id").
      scope(:find)

  # select products which have an option of the given type
  # this sets up testing on specific option values, eg colour = red
  # the optional argument supports filtering by multi options, eg colour = red and 
  #   size = small, which need separate joins if done a property at a time
  # this version discards products which don't have the given option (the outer join
  #   version is a bit more complex because we need to control the order of joins)
  # TODO: speed test on nest vs join
  Product.named_scope :with_option,
    lambda {|opt_type,*args|
      name   = args.empty? ? "option_types" : args.first
      opt_id = case opt_type
                 when OptionType then opt_type.id 
                 when Fixnum     then opt_type
               end
      return {} if opt_id.nil?
      Product.with_variant_options.
              scoped(:joins => "join (select presentation, id from option_values where option_type_id = #{opt_id}) #{name} on #{name}.id = option_values_variants.option_value_id").
              scope(:find)
    }

end
