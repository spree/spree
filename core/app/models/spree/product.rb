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
  class Product < Spree::Base
    extend FriendlyId
    friendly_id :slug_candidates, use: :history

    acts_as_paranoid

    has_many :product_option_types, dependent: :destroy, inverse_of: :product
    has_many :option_types, through: :product_option_types
    has_many :product_properties, dependent: :destroy, inverse_of: :product
    has_many :properties, through: :product_properties

    has_many :classifications, dependent: :delete_all, inverse_of: :product
    has_many :taxons, through: :classifications, before_remove: :remove_taxon
    has_and_belongs_to_many :promotion_rules, join_table: :spree_products_promotion_rules

    belongs_to :tax_category, class_name: 'Spree::TaxCategory'
    belongs_to :shipping_category, class_name: 'Spree::ShippingCategory', inverse_of: :products

    has_one :master,
      -> { where is_master: true },
      inverse_of: :product,
      class_name: 'Spree::Variant'

    has_many :variants,
      -> { where(is_master: false).order("#{::Spree::Variant.quoted_table_name}.position ASC") },
      inverse_of: :product,
      class_name: 'Spree::Variant'

    has_many :variants_including_master,
      -> { order("#{::Spree::Variant.quoted_table_name}.position ASC") },
      inverse_of: :product,
      class_name: 'Spree::Variant',
      dependent: :destroy

    has_many :prices, -> { order('spree_variants.position, spree_variants.id, currency') }, through: :variants

    has_many :stock_items, through: :variants_including_master

    has_many :line_items, through: :variants_including_master
    has_many :orders, through: :line_items

    delegate_belongs_to :master, :sku, :price, :currency, :display_amount, :display_price, :weight, :height, :width, :depth, :is_master, :has_default_price?, :cost_currency, :price_in, :amount_in

    delegate_belongs_to :master, :cost_price

    delegate :images, to: :master, prefix: true
    alias_method :images, :master_images

    has_many :variant_images, -> { order(:position) }, source: :images, through: :variants_including_master

    after_create :set_master_variant_defaults
    after_create :add_associations_from_prototype
    after_create :build_variants_from_option_values_hash, if: :option_values_hash

    after_destroy :punch_slug
    after_restore :update_slug_history

    after_initialize :ensure_master

    after_save :save_master
    after_save :run_touch_callbacks, if: :anything_changed?
    after_save :reset_nested_changes
    after_touch :touch_taxons

    before_validation :normalize_slug, on: :update
    before_validation :validate_master

    validates :meta_keywords, length: { maximum: 255 }
    validates :meta_title, length: { maximum: 255 }
    validates :name, presence: true
    validates :price, presence: true, if: proc { Spree::Config[:require_master_price] }
    validates :shipping_category_id, presence: true
    validates :slug, length: { minimum: 3 }, allow_blank: true, uniqueness: true

    attr_accessor :option_values_hash

    accepts_nested_attributes_for :product_properties, allow_destroy: true, reject_if: lambda { |pp| pp[:property_name].blank? }

    alias :options :product_option_types

    self.whitelisted_ransackable_associations = %w[stores variants_including_master master variants]
    self.whitelisted_ransackable_attributes = %w[description name slug]

    # the master variant is not a member of the variants array
    def has_variants?
      variants.any?
    end

    def tax_category
      if self[:tax_category_id].nil?
        TaxCategory.where(is_default: true).first
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
        product_option_types.create(option_type_id: id) unless product_option_types.pluck(:option_type_id).include?(id)
      end
    end

    # for adding products which are closely related to existing ones
    # define "duplicate_extra" for site-specific actions, eg for additional fields
    def duplicate
      duplicator = ProductDuplicator.new(self)
      duplicator.duplicate
    end

    # use deleted? rather than checking the attribute directly. this
    # allows extensions to override deleted? if they want to provide
    # their own definition.
    def deleted?
      !!deleted_at
    end

    # determine if product is available.
    # deleted products and products with nil or future available_on date
    # are not available
    def available?
      !(available_on.nil? || available_on.future?) && !deleted?
    end

    # split variants list into hash which shows mapping of opt value onto matching variants
    # eg categorise_variants_from_option(color) => {"red" -> [...], "blue" -> [...]}
    def categorise_variants_from_option(opt_type)
      return {} unless option_types.include?(opt_type)
      variants.active.group_by { |v| v.option_values.detect { |o| o.option_type == opt_type} }
    end

    def self.like_any(fields, values)
      where fields.map { |field|
        values.map { |value|
          arel_table[field].matches("%#{value}%")
        }.inject(:or)
      }.inject(:or)
    end

    # Suitable for displaying only variants that has at least one option value.
    # There may be scenarios where an option type is removed and along with it
    # all option values. At that point all variants associated with only those
    # values should not be displayed to frontend users. Otherwise it breaks the
    # idea of having variants
    def variants_and_option_values(current_currency = nil)
      variants.includes(:option_values).active(current_currency).select do |variant|
        variant.option_values.any?
      end
    end

    def empty_option_values?
      options.empty? || options.any? do |opt|
        opt.option_type.option_values.empty?
      end
    end

    def property(property_name)
      return nil unless prop = properties.find_by(name: property_name)
      product_properties.find_by(property: prop).try(:value)
    end

    def set_property(property_name, property_value)
      ActiveRecord::Base.transaction do
        # Works around spree_i18n #301
        property = if Property.exists?(name: property_name)
          Property.where(name: property_name).first
        else
          Property.create(name: property_name, presentation: property_name)
        end
        product_property = ProductProperty.where(product: self, property: property).first_or_initialize
        product_property.value = property_value
        product_property.save!
      end
    end

    def possible_promotions
      promotion_ids = promotion_rules.map(&:promotion_id).uniq
      Spree::Promotion.advertised.where(id: promotion_ids).reject(&:expired?)
    end

    def total_on_hand
      if any_variants_not_track_inventory?
        Float::INFINITY
      else
        stock_items.sum(:count_on_hand)
      end
    end

    # Master variant may be deleted (i.e. when the product is deleted)
    # which would make AR's default finder return nil.
    # This is a stopgap for that little problem.
    def master
      super || variants_including_master.with_deleted.where(is_master: true).first
    end

    private

    def add_associations_from_prototype
      if prototype_id && prototype = Spree::Prototype.find_by(id: prototype_id)
        prototype.properties.each do |property|
          product_properties.create(property: property)
        end
        self.option_types = prototype.option_types
        self.taxons = prototype.taxons
      end
    end

    def any_variants_not_track_inventory?
      return true unless Spree::Config.track_inventory_levels
      if variants_including_master.loaded?
        variants_including_master.any? { |v| !v.track_inventory? }
      else
        variants_including_master.where(track_inventory: false).exists?
      end
    end

    # Builds variants from a hash of option types & values
    def build_variants_from_option_values_hash
      ensure_option_types_exist_for_values_hash
      values = option_values_hash.values
      values = values.inject(values.shift) { |memo, value| memo.product(value).map(&:flatten) }

      values.each do |ids|
        variant = variants.create(
          option_value_ids: ids,
          price: master.price
        )
      end
      save
    end

    def ensure_master
      return unless new_record?
      self.master ||= build_master
    end

    def normalize_slug
      self.slug = normalize_friendly_id(slug)
    end

    def punch_slug
      # punch slug with date prefix to allow reuse of original
      update_column :slug, "#{Time.now.to_i}_#{slug}"[0..254] unless frozen?
    end

    def update_slug_history
      self.save!
    end

    def anything_changed?
      changed? || @nested_changes
    end

    def reset_nested_changes
      @nested_changes = false
    end

    def master_updated?
      master && (
        master.new_record? ||
        master.changed? ||
        (
          master.default_price &&
          (
            master.default_price.new_record? ||
            master.default_price.changed?
          )
        )
      )
    end

    # there's a weird quirk with the delegate stuff that does not automatically save the delegate object
    # when saving so we force a save using a hook
    # Fix for issue #5306
    def save_master
      if master_updated?
        master.save!
        @nested_changes = true
      end
    end

    # If the master cannot be saved, the Product object will get its errors
    # and will be destroyed
    def validate_master
      # We call master.default_price here to ensure price is initialized.
      # Required to avoid Variant#check_price validation failing on create.
      unless master.default_price && master.valid?
        master.errors.each do |att, error|
          self.errors.add(att, error)
        end
      end
    end

    # ensures the master variant is flagged as such
    def set_master_variant_defaults
      master.is_master = true
    end

    # Try building a slug based on the following fields in increasing order of specificity.
    def slug_candidates
      [
        :name,
        [:name, :sku]
      ]
    end

    def run_touch_callbacks
      run_callbacks(:touch)
    end

    def taxon_and_ancestors
      taxons.map(&:self_and_ancestors).flatten.uniq
    end

    # Get the taxonomy ids of all taxons assigned to this product and their ancestors.
    def taxonomy_ids
      taxon_and_ancestors.map(&:taxonomy_id).flatten.uniq
    end

    # Iterate through this products taxons and taxonomies and touch their timestamps in a batch
    def touch_taxons
      Spree::Taxon.where(id: taxon_and_ancestors.map(&:id)).update_all(updated_at: Time.current)
      Spree::Taxonomy.where(id: taxonomy_ids).update_all(updated_at: Time.current)
    end

    def remove_taxon(taxon)
      removed_classifications = classifications.where(taxon: taxon)
      removed_classifications.each &:remove_from_list
    end
  end
end

require_dependency 'spree/product/scopes'
