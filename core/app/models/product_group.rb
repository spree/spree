# *ProductGroups* are used for creating and managing sets of products.
# Product group can be either anonymous(adhoc) or named.
#
# Anonymous Product groups are created by combining product scopes generated from url
# in 2 formats:
#
#   /t/*taxons/s/name_of_scope/comma_separated_arguments/name_of_scope_that_doesn_take_any//order
#   */s/name_of_scope/comma_separated_arguments/name_of_scope_that_doesn_take_any//order
#
# Named product groups can be created from anonymous ones, lub from another named scope
# (using ProductGroup.from_url method).
# Named product groups have pernament urls, that don't change even after changes
# to scopes are made, and come in two types.
#
#   /t/*taxons/pg/named_product_group
#   */pg/named_product_group
#
# first one is used for combining named scope with taxons, named product group can
# have #in_taxon or #taxons_name_eq scope defined, result should combine both
# and return products that exist in both taxons.
#
# ProductGroup#dynamic_products returns chain of named scopes generated from order and
# product scopes. So you can do counting, calculations etc, on resulted set of products,
# without retriving all records.
#
# ProductGroup operates on named scopes defined for product in Scopes::Product,
# or generated automatically by Searchlogic
#
class ProductGroup < ActiveRecord::Base
  validates_presence_of :name
  validates_associated :product_scopes

  before_save :set_permalink
  after_save :update_memberships

  has_and_belongs_to_many :cached_products, :class_name => "Product"
  # name
  has_many :product_scopes
  accepts_nested_attributes_for :product_scopes 

  # Testing utility: creates new *ProductGroup* from search permalink url.
  # Follows conventions for accessing PGs from URLs, as decoded in routes
  def self.from_url(url)
    pg = nil;
    case url
    when /\/t\/(.+?)\/s\/(.+)/  then taxons = $1; attrs = $2;
    when /\/t\/(.+?)\/pg\/(.+)/ then taxons = $1; pg_name = $2;
    when /(.*?)\/s\/(.+)/       then attrs = $2;
    when /(.*?)\/pg\/(.+)/      then pg_name = $2;
    else                        return(nil)
    end

    if pg_name && opg = ProductGroup.find_by_permalink(pg_name)
      pg = new.from_product_group(opg)
    elsif attrs
      attrs = url.split("/")
      pg = new.from_route(attrs)
    end
    taxon = taxons && taxons.split("/").last
    pg.add_scope("in_taxon", taxon) if taxon
    
    pg
  end

  def from_product_group(opg)
    self.product_scopes = opg.product_scopes.map{|ps|
      ps = ps.clone;
      ps.product_group_id = nil;
      ps.product_group = self;
      ps
    }
    self
  end

  def from_route(attrs)
    self.order_scope = attrs.pop if attrs.length % 2 == 1
    attrs.each_slice(2) do |scope|
      next unless Product.condition?(scope.first)
      add_scope(scope.first, scope.last.split(","))
    end
    self
  end

  def from_search(search_hash)
    search_hash.each_pair do |scope_name, scope_attribute|
      add_scope(scope_name, scope_attribute)
    end
    
    self
  end

  def add_scope(scope_name, arguments=[])
    self.product_scopes << ProductScope.new({
        :name => scope_name.to_s,
        :arguments => [*arguments]
      })
    self
  end

  def apply_on(scopish, use_order = true)
    # There's bug in AR, it doesn't merge :order, instead it takes order
    # from first nested_scope so we have to apply ordering FIRST.
    # see #2253 on rails LH
    base_product_scope = scopish
    if use_order && !self.order_scope.blank? && Product.condition?(self.order_scope)
      base_product_scope = base_product_scope.send(self.order_scope)
    end

    return self.product_scopes.reject {|s|
             s.is_ordering?
           }.inject(base_product_scope){|result, scope|
             scope.apply_on(result)
           }
  end

  # returns chain of named scopes generated from order scope and product scopes.
  def dynamic_products(use_order = true)
    apply_on(Product.scoped(nil), use_order)
  end

  # Does the final ordering if requested
  # TODO: move the order stuff out of the above - is superfluous now
  def products(use_order = true)
    cached_group = Product.in_cached_group(self)	
    if cached_group.limit(1).blank?
      dynamic_products(use_order)
    elsif !use_order
      cached_group
    else
      product_scopes.select {|s| 
        s.is_ordering?
      }.inject(cached_group) {|res,order| 
        order.apply_on(res)
      }
    end
  end

  def include?(product)
    res = apply_on(Product.id_equals(product.id), false)
    res.count > 0
  end

  def scopes_to_hash
    result = {}
    self.product_scopes.each do |scope|
      result[scope.name] = scope.arguments
    end
    result
  end

  # generates ProductGroup url
  def to_url
    if (new_record? || name.blank?)
      result = ""
      result+= self.product_scopes.map{|ps|
        [ps.name, ps.arguments.join(",")]
      }.flatten.join('/')
      result+= self.order_scope if self.order_scope
    
      result
    else
      name.to_url
    end
  end

  def set_permalink
    self.permalink = self.name.to_url
  end
  
  def update_memberships
    # wipe everything directly to avoid expensive in-rails sorting
    ActiveRecord::Base.connection.execute "DELETE FROM product_groups_products WHERE product_group_id = #{self.id}"

    # and generate the new group entirely in SQL
    ActiveRecord::Base.connection.execute "INSERT INTO product_groups_products #{dynamic_products(false).scoped(:select => "products.id, #{self.id}").to_sql}"
  end

  def generate_preview(size = Spree::Config[:admin_pgroup_preview_size])
    count = self.class.count_by_sql ["SELECT COUNT(*) FROM product_groups_products WHERE product_groups_products.product_group_id = ?", self]

    return count, products.limit(size)
  end

  def to_s
    "<ProductGroup" + (id && "[#{id}]").to_s + ":'#{to_url}'>"
  end
  
  def order_scope
    if scope = product_scopes.detect {|s| s.is_ordering?}
      scope.name
    end
  end
  def order_scope=(scope_name)
    if scope = product_scopes.detect {|s| s.is_ordering?}
      scope.update_attribute(:name, scope_name)
    else
      self.product_scopes.build(:name => scope_name, :arguments => [])
    end    
  end

  # Build a new product group with a scope to filter by specified products
  def self.new_from_products(products, attrs = {})
    pg = new(attrs)
    pg.product_scopes.build(:name => 'with_ids', :arguments => [products.map(&:id).join(',')])
    pg
  end

end
