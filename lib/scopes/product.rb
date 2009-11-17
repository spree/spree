module Scopes::Product
  #TODO: change this to array pairs so we preserve order?

  SCOPES = {
    # Scopes for selecting products based on taxon
    :taxon => {
      :taxons_name_eq => [:taxon_name],
      :in_taxons => [:taxon_names],
    },
    # product selection based on name, or search
    :search => {
      :in_name => [:words],
      :in_name_or_keywords => [:words],
      :in_name_or_description => [:words],
    },
    # Scopes for selecting products based on option types and properties
    :values => {
      :with => [:value],
      :with_property => [:property],
      :with_property_value => [:property, :value],
      :with_option => [:option],
      :with_option_value => [:option, :value],
    },
    # product selection based upon master price
    :price => {
      :price_between => [:low, :high],
      :master_price_lte => [:amount],
      :master_price_gte => [:amount],
    },
  }

  ORDERING = [
    :ascend_by_updated_at,
    :descend_by_updated_at,
    :ascend_by_name,
    :descend_by_name,
    :ascend_by_master_price,
    :descend_by_master_price,
    :by_popularity,
  ]

  # default product scope only lists available and non-deleted products
  ::Product.named_scope :active,      lambda { |*args|
    Product.not_deleted.available(args.first).scope(:find)
  }

  ::Product.named_scope :not_deleted, {
    :conditions => "products.deleted_at is null"
  }
  ::Product.named_scope :available,   lambda { |*args|
    { :conditions => ["products.available_on <= ?", args.first || Time.zone.now] }
  }

  ::Product.named_scope :keywords, lambda{|query|
    Spree::Config.searcher.get_products_conditions_for(query)
  }

  ::Product.named_scope :price_between, lambda {|low,high|
    { :joins => :master, :conditions => ["variants.price BETWEEN ? AND ?", low, high] }
  }

  # This scope selects products in taxon AND all it's ancestors
  # If you need products only within one taxon use
  #
  #   Product.taxons_id_eq(x)
  #
  Product.named_scope :in_taxon, lambda {|taxon|
    taxon = get_taxons(taxon).first
    taxon ? {:joins => :taxons}.merge(taxon.self_and_descendants.scope(:find)) : {}
  }

  # This scope selects products in all taxons AND all it's ancestors
  # If you need products only within one taxon use
  #
  #   Product.taxons_id_eq([x,y])
  #
  Product.named_scope :in_taxons, lambda {|*taxons|
    taxons = get_taxons(taxons)
    taxons.first ? prepare_taxon_conditions(taxons) : {}
  }

  # a scope that finds all products having property specified by name, object or id
  Product.named_scope :with_property, lambda {|property|
    conditions = case property
    when String   then ["properties.name = ?", property]
    when Property then ["properties.id = ?", property.id]
    else               ["properties.id = ?", property.to_i]
    end

    {
      :joins => :properties,
      :conditions => conditions
    }
  }

  # a scope that finds all products having property specified by name, object or id
  Product.named_scope :with_option, lambda {|option|
    conditions = case option
    when String     then ["option_types.name = ?", option]
    when OptionType then ["option_types.id = ?",   option.id]
    else                 ["option_types.id = ?",   option.to_i]
    end

    {
      :joins => :option_types,
      :conditions => conditions
    }
  }

  # a simple test for product with a certain property-value pairing
  # it can't test for NULLs and can't be cascaded - see :with_property
  Product.named_scope :with_property_value, lambda { |property, value|
    conditions = case property
    when String   then ["properties.name = ?", property]
    when Property then ["properties.id = ?", property.id]
    else               ["properties.id = ?", property.to_i]
    end
    conditions = ["product_properties.value = ? AND #{conditions[0]}", value, conditions[1]]

    {
      :joins => :properties,
      :conditions => conditions
    }
  }   # coded this way to demonstrate composition

  # a scope that finds all products having property specified by name, object or id
  Product.named_scope :with_option_value, lambda {|option, value|
    option_type_id = case option
    when String     then OptionType.find_by_name(option).id
    when OptionType then option.id
    else                 option.to_i
    end
    conditions = [
      "option_values.name = ? AND option_values.option_type_id = ?",
      value, option_type_id
    ]

    {
      :joins => {:variants => :option_values},
      :conditions => conditions
    }
  }

  # finds product having option value OR product_property
  Product.named_scope :with, lambda{|value|
    {
      :conditions => ["option_values.name = ? OR product_properties.value = ?", value, value],
      :joins => {:variants => :option_values, :product_properties => []}
    }
  }

  Product.scope_procedure :in_name, lambda{|words|
    Product.name_like_any(words.split(/[,\s]/).map(&:strip))
  }

  Product.scope_procedure :in_name_or_keywords, lambda{|words|
    Product.name_or_meta_keywords_like_any(words.split(/[,\s]/).map(&:strip))
  }

  Product.scope_procedure :in_name_or_description, lambda{|words|
    Product.name_or_description_or_meta_description_or_meta_keywords_like_any(
      words.split(/[,\s]/).map(&:strip)
    )
  }

  # Sorts products from most popular (poularity is extracted from how many
  # times use has put product in cart, not completed orders)
  #
  # there is alternative faster and more elegant solution, it has small drawback though,
  # it doesn stack with other scopes :/
  #
  Product.named_scope :by_popularity, lambda{
    # :joins => "LEFT OUTER JOIN (SELECT line_items.variant_id as vid, COUNT(*) as cnt FROM line_items GROUP BY line_items.variant_id) AS popularity_count ON variants.id = vid",
    # :order => 'COALESCE(cnt, 0) DESC'
    {
      :joins => :master,
      :order => <<SQL
         COALESCE((
           SELECT
             COUNT(*)
           FROM
             line_items, variants as popular_variants
           GROUP BY
             line_items.variant_id
           HAVING
             line_items.variant_id = popular_variants.id AND
             popular_variants.product_id = products.id
         ), 0) DESC
SQL
    }
  }

  def self.get_taxons(*ids_or_records_or_names)
    ids_or_records_or_names.flatten.map { |t|
      case t
      when Integer then Taxon.find_by_id(t)
      when ActiveRecord::Base then t
      when String
        Taxon.find_by_name(t) ||
        Taxon.find(:first, :conditions => [
          "taxons.permalink LIKE ? OR taxons.permalink = ?", "%/#{t}/", "#{t}/"
        ])
      end
    }.compact.uniq
  end

  def self.prepare_taxon_conditions(taxons)
    conditions = taxons.map{|taxon|
      taxon.self_and_descendants.scope(:find)[:conditions]
    }.inject([[]]){|result, scope|
      result.first << scope.shift
      result +=  scope;
      result
    }
    conditions[0] = "("+conditions[0].join(") OR (")+")"

    {
      :joins => :taxons,
      :conditions => conditions,
    }
  end
end
