# PRODUCTS
# Products represent an entity for sale in a store.
# Products can have variations, called variants
# Products properties include description, permalink, availability,
#   shipping category, etc. that do not change by variant.
#
# MASTER VARIANT
# Every product has one master variant, which stores master price and sku, size and weight, etc.
# The master variant does not have option values associated with it.
# Price, SKU, size, weight, etc. are all delegated to the master variant.
# Contains on_hand inventory levels only when there are no variants for the product.
#
# VARIANTS
# All variants can access the product properties directly (via reverse delegation).
# Inventory units are tied to Variant.
# The master variant can have inventory units, but not option values.
# All other variants have option values and may have inventory units.
# Sum of on_hand each variant's inventory level determine "on_hand" level for the product.
#
module Spree
  class Product < ActiveRecord::Base
    has_many :product_option_types, :dependent => :destroy
    has_many :option_types, :through => :product_option_types
    has_many :product_properties, :dependent => :destroy
    has_many :properties, :through => :product_properties
    belongs_to :tax_category, :class_name => "Spree::TaxCategory"
    has_and_belongs_to_many :taxons, :join_table => 'spree_products_taxons'
    belongs_to :shipping_category, :class_name => "Spree::ShippingCategory"

    has_one :master,
      :class_name => 'Spree::Variant',
      :conditions => ["#{Variant.quoted_table_name}.is_master = ?", true]

    delegate_belongs_to :master, :sku, :price, :weight, :height, :width, :depth, :is_master
    delegate_belongs_to :master, :cost_price if Variant.table_exists? && Variant.column_names.include?('cost_price')

    after_create :set_master_variant_defaults
    after_create :add_properties_and_option_types_from_prototype
    after_create :build_variants_from_option_values_hash, :if => :option_values_hash
    before_save :recalculate_count_on_hand
    after_save :save_master
    after_save :set_master_on_hand_to_zero_when_product_has_variants

    has_many :variants,
      :class_name => 'Spree::Variant',
      :conditions => ["#{::Spree::Variant.quoted_table_name}.is_master = ? AND #{::Spree::Variant.quoted_table_name}.deleted_at IS NULL", false],
      :order => "#{::Spree::Variant.quoted_table_name}.position ASC"

    has_many :variants_including_master,
      :class_name => 'Spree::Variant',
      :conditions => ["#{::Spree::Variant.quoted_table_name}.deleted_at IS NULL"],
      :dependent => :destroy

    has_many :variants_with_only_master,
      :class_name => 'Spree::Variant',
      :conditions => ["#{::Spree::Variant.quoted_table_name}.deleted_at IS NULL AND #{::Spree::Variant.quoted_table_name}.is_master = ?", true],
      :dependent => :destroy

    accepts_nested_attributes_for :variants, :allow_destroy => true

    def variant_images
      Image.joins("LEFT JOIN #{Variant.quoted_table_name} ON #{Variant.quoted_table_name}.id = #{Asset.quoted_table_name}.viewable_id").
      where("#{Variant.quoted_table_name}.product_id = #{self.id}").
      where("#{Asset.quoted_table_name}.viewable_type = '#{Variant.name}'").
      order("#{Asset.quoted_table_name}.position").
      extend(Spree::Core::RelationSerialization)
    end

    alias_method :images, :variant_images

    validates :name, :price, :permalink, :presence => true

    attr_accessor :option_values_hash

    attr_accessible :name, :description, :available_on, :permalink, :meta_description,
                    :meta_keywords, :price, :sku, :deleted_at, :prototype_id,
                    :option_values_hash, :on_hand, :weight, :height, :width, :depth,
                    :shipping_category_id, :tax_category_id, :product_properties_attributes,
                    :variants_attributes, :taxon_ids

    attr_accessible :cost_price if Variant.table_exists? && Variant.column_names.include?('cost_price')


    accepts_nested_attributes_for :product_properties, :allow_destroy => true, :reject_if => lambda { |pp| pp[:property_name].blank? }

    make_permalink :order => :name

    alias :options :product_option_types

    after_initialize :ensure_master

    def ensure_master
      return unless new_record?
      self.master ||= Variant.new
    end

    def to_param
      permalink.present? ? permalink : (permalink_was || name.to_s.to_url)
    end

    # returns true if the product has any variants (the master variant is not a member of the variants array)
    def has_variants?
      variants.any?
    end

    # returns the number of inventory units "on_hand" for this product
    def on_hand
      has_variants? ? variants.inject(0) { |sum, v| sum + v.on_hand } : master.on_hand
    end

    # adjusts the "on_hand" inventory level for the product up or down to match the given new_level
    def on_hand=(new_level)
      raise 'cannot set on_hand of product with variants' if has_variants? && Spree::Config[:track_inventory_levels]
      master.on_hand = new_level
    end

    # Returns true if there are inventory units (any variant) with "on_hand" state for this product
    def has_stock?
      master.in_stock? || variants.any?(&:in_stock?)
    end

    def tax_category
      if self[:tax_category_id].nil?
        TaxCategory.where(:is_default => true).first
      else
        TaxCategory.find(self[:tax_category_id])
      end
    end

    # Adding properties and option types on creation based on a chosen prototype
    attr_reader :prototype_id
    def prototype_id=(value)
      @prototype_id = value.to_i
    end

    # Ensures option_types and product_option_types exist for keys in option_values_hash
    def ensure_option_types_exist_for_values_hash
      return if option_values_hash.nil?
      option_values_hash.keys.map(&:to_i).each do |id|
        self.option_type_ids << id unless option_type_ids.include?(id)
        product_option_types.create({:option_type_id => id}, :without_protection => true) unless product_option_types.map(&:option_type_id).include?(id)
      end
    end

    # for adding products which are closely related to existing ones
    # define "duplicate_extra" for site-specific actions, eg for additional fields
    def duplicate
      p = self.dup
      p.name = 'COPY OF ' + name
      p.deleted_at = nil
      p.created_at = p.updated_at = nil
      p.taxons = taxons

      p.product_properties = product_properties.map { |q| r = q.dup; r.created_at = r.updated_at = nil; r }

      image_dup = lambda { |i| j = i.dup; j.attachment = i.attachment.clone; j }

      variant = master.dup
      variant.sku = 'COPY OF ' + master.sku
      variant.deleted_at = nil
      variant.images = master.images.map { |i| image_dup.call i }
      p.master = variant

      # don't dup the actual variants, just the characterising types
      p.option_types = option_types if has_variants?

      # allow site to do some customization
      p.send(:duplicate_extra, self) if p.respond_to?(:duplicate_extra)
      p.save!
      p
    end

    # use deleted? rather than checking the attribute directly. this
    # allows extensions to override deleted? if they want to provide
    # their own definition.
    def deleted?
      !!deleted_at
    end

    # split variants list into hash which shows mapping of opt value onto matching variants
    # eg categorise_variants_from_option(color) => {"red" -> [...], "blue" -> [...]}
    def categorise_variants_from_option(opt_type)
      return {} unless option_types.include?(opt_type)
      variants.active.group_by { |v| v.option_values.detect { |o| o.option_type == opt_type} }
    end

    def self.like_any(fields, values)
      where_str = fields.map { |field| Array.new(values.size, "#{self.quoted_table_name}.#{field} #{LIKE} ?").join(' OR ') }.join(' OR ')
      self.where([where_str, values.map { |value| "%#{value}%" } * fields.size].flatten)
    end

    def empty_option_values?
      options.empty? || options.any? do |opt|
        opt.option_type.option_values.empty?
      end
    end

    def property(property_name)
      return nil unless prop = properties.find_by_name(property_name)
      product_properties.find_by_property_id(prop.id).try(:value)
    end

    def set_property(property_name, property_value)
      prop = Spree::Property.find_or_initialize_by_name(property_name) do |p|
        p.presentation = property_name
        p.save!
      end

      prod_prop = Spree::ProductProperty.find_or_initialize_by_product_id_and_property_id(self.id, prop.id)
      prod_prop.value = property_value
      prod_prop.save!
    end

    private

      # Builds variants from a hash of option types & values
      def build_variants_from_option_values_hash
        ensure_option_types_exist_for_values_hash
        values = option_values_hash.values
        values = values.inject(values.shift) { |memo, value| memo.product(value).map(&:flatten) }

        values.each do |ids|
          variant = variants.create({ :option_value_ids => ids, :price => master.price }, :without_protection => true)
        end
        save
      end

      def add_properties_and_option_types_from_prototype
        if prototype_id && prototype = Spree::Prototype.find_by_id(prototype_id)
          prototype.properties.each do |property|
            product_properties.create({:property => property}, :without_protection => true)
          end
          self.option_types = prototype.option_types
        end
      end

      def recalculate_count_on_hand
        product_count_on_hand = has_variants? ?
          variants.sum(:count_on_hand) : (master ? master.count_on_hand : 0)
        self.count_on_hand = product_count_on_hand
      end

      # the master on_hand is meaningless once a product has variants as the inventory
      # units are now "contained" within the product variants
      def set_master_on_hand_to_zero_when_product_has_variants
        master.on_hand = 0 if has_variants? && Spree::Config[:track_inventory_levels]
      end

      # ensures the master variant is flagged as such
      def set_master_variant_defaults
        master.is_master = true
      end

      # there's a weird quirk with the delegate stuff that does not automatically save the delegate object
      # when saving so we force a save using a hook.
      def save_master
        master.save if master && (master.changed? || master.new_record?)
      end
  end
end

require_dependency 'spree/product/scopes'
