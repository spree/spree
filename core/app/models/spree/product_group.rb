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
# or generated automatically by meta_search
#
module Spree
  class ProductGroup < ActiveRecord::Base
    validates :name, :presence => true # TODO ensure that this field is defined as not_null
    validates_associated :product_scopes

    after_save :update_memberships

    has_and_belongs_to_many :cached_products, :class_name => 'Spree::Product',
                                              :join_table => 'spree_product_groups_products'
    has_many :product_scopes
    accepts_nested_attributes_for :product_scopes

    make_permalink

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
        attrs = url.split('/')
        pg = new.from_route(attrs)
      end
      taxon = taxons && taxons.split('/').last
      pg.add_scope('in_taxon', taxon) if taxon

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
        next unless Product.respond_to?(scope.first)
        add_scope(scope.first, scope.last.split(','))
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
      if scope_name.to_s !~ /eval|send|system|[^a-z0-9_!?]/
        self.product_scopes << ProductScope.new({
            :name => scope_name.to_s,
            :arguments => [*arguments]
          })
      else
        raise ArgumentError.new("'#{scope_name}` can't be used as scope")
      end
      self
    end

    def apply_on(scopish, use_order = true)
      # There's bug in AR, it doesn't merge :order, instead it takes order
      # from first nested_scope so we have to apply ordering FIRST.
      # see #2253 on rails LH
      base_product_scope = scopish
      if use_order && !self.order_scope.blank? && Product.respond_to?(self.order_scope.intern)
        base_product_scope = base_product_scope.send(self.order_scope)
      end

      return self.product_scopes.reject { |s| s.is_ordering? }.inject(base_product_scope) do |result, scope|
        scope.apply_on(result)
      end

    end

    # returns chain of named scopes generated from order scope and product scopes.
    def dynamic_products(use_order = true)
      apply_on(Product.group_by_products_id, use_order)
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
        product_scopes.select { |s|
          s.is_ordering?
        }.inject(cached_group) { |res,order|
          order.apply_on(res)
        }
      end
    end

    def include?(product)
      res = apply_on(Product.where(:id => product.id), false)
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
    def permalink
      self.read_attribute(:permalink) || name.to_s.to_url
    end

    alias_method :to_url, :permalink

    def update_memberships
      # wipe everything directly to avoid expensive in-rails sorting
      ActiveRecord::Base.connection.execute "DELETE FROM spree_product_groups_products WHERE product_group_id = #{self.id}"

      # and generate the new group entirely in SQL
      ActiveRecord::Base.connection.execute "INSERT INTO spree_product_groups_products #{dynamic_products(false).scoped(:select => "spree_products.id, #{self.id}").to_sql}"
    end

    def generate_preview(size = Spree::Config[:admin_pgroup_preview_size])
      count = self.class.count_by_sql ["SELECT COUNT(*) FROM spree_product_groups_products WHERE spree_product_groups_products.product_group_id = ?", self]

      return count, products.limit(size)
    end

    def to_s
      "<Spree::ProductGroup" + (id && "[#{id}]").to_s + ":'#{to_url}'>"
    end

    def to_param
      self.permalink
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
end
