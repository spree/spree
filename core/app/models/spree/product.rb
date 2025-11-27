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
  class Product < Spree.base_class
    acts_as_paranoid
    acts_as_taggable_on :tags, :labels
    auto_strip_attributes :name

    include Spree::ProductScopes
    include Spree::MultiStoreResource
    include Spree::TranslatableResource
    include Spree::MemoizedData
    include Spree::Metafields
    include Spree::Metadata
    include Spree::Linkable
    include Spree::Product::Webhooks
    include Spree::Product::Slugs
    if defined?(Spree::VendorConcern)
      include Spree::VendorConcern
    end

    MEMOIZED_METHODS = %w[total_on_hand taxonomy_ids taxon_and_ancestors category
                          default_variant_id tax_category default_variant
                          default_image secondary_image
                          purchasable? in_stock? backorderable? has_variants? digital?]

    STATUS_TO_WEBHOOK_EVENT = {
      'active' => 'activated',
      'draft' => 'drafted',
      'archived' => 'archived'
    }.freeze

    TRANSLATABLE_FIELDS = %i[name description slug meta_description meta_title].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: !Spree.always_use_translations?)

    self::Translation.class_eval do
      if defined?(PgSearch)
        include PgSearch::Model

        pg_search_scope :search_by_name, against: { name: 'A', meta_title: 'B' }, using: { trigram: { threshold: 0.3, word_similarity: true } }
      end
    end

    # we need to have this callback before any dependent: :destroy associations
    # https://github.com/rails/rails/issues/3458
    before_destroy :ensure_not_in_complete_orders

    has_many :product_option_types, -> { order(:position) }, dependent: :destroy, inverse_of: :product
    has_many :option_types, through: :product_option_types
    has_many :product_properties, dependent: :destroy, inverse_of: :product
    has_many :properties, through: :product_properties

    has_many :classifications, -> { order(created_at: :asc) }, dependent: :delete_all, inverse_of: :product
    has_many :taxons, through: :classifications, before_remove: :remove_taxon
    has_many :taxonomies, through: :taxons

    has_many :product_promotion_rules, class_name: 'Spree::ProductPromotionRule'
    has_many :promotion_rules, through: :product_promotion_rules, class_name: 'Spree::PromotionRule'

    has_many :promotions, through: :promotion_rules, class_name: 'Spree::Promotion'

    has_many :possible_promotions, -> { advertised.active }, through: :promotion_rules,
                                                             class_name: 'Spree::Promotion',
                                                             source: :promotion

    belongs_to :tax_category, class_name: 'Spree::TaxCategory'
    belongs_to :shipping_category, class_name: 'Spree::ShippingCategory', inverse_of: :products
    has_many :shipping_methods, through: :shipping_category, class_name: 'Spree::ShippingMethod'

    has_one :master,
            -> { where is_master: true },
            inverse_of: :product,
            class_name: 'Spree::Variant'

    has_many :variants,
             -> { where(is_master: false).order(:position) },
             inverse_of: :product,
             class_name: 'Spree::Variant'

    has_many :variants_including_master,
             -> { order(:position) },
             inverse_of: :product,
             class_name: 'Spree::Variant',
             dependent: :destroy

    has_many :prices, -> { order('spree_variants.position, spree_variants.id, currency') }, through: :variants

    has_many :stock_items, through: :variants_including_master

    has_many :line_items, through: :variants_including_master
    has_many :orders, through: :line_items

    has_many :variant_images, -> { order(:position) }, source: :images, through: :variants_including_master
    has_many :variant_images_without_master, -> { order(:position) }, source: :images, through: :variants

    has_many :option_value_variants, class_name: 'Spree::OptionValueVariant', through: :variants
    has_many :option_values, class_name: 'Spree::OptionValue', through: :variants

    has_many :prices_including_master, -> { non_zero }, through: :variants_including_master, source: :prices

    has_many :store_products, class_name: 'Spree::StoreProduct'
    has_many :stores, through: :store_products, class_name: 'Spree::Store'
    has_many :digitals, through: :variants_including_master

    after_initialize :ensure_master
    after_initialize :assign_default_tax_category

    before_validation :validate_master
    before_validation :ensure_default_shipping_category

    after_create :add_associations_from_prototype
    after_create :build_variants_from_option_values_hash, if: :option_values_hash

    after_save :save_master
    after_save :run_touch_callbacks, if: :anything_changed?
    after_save :reset_nested_changes
    after_touch :touch_taxons

    after_commit :auto_match_taxons, if: :eligible_for_taxon_matching?

    with_options length: { maximum: 255 }, allow_blank: true do
      validates :meta_keywords
      validates :meta_title
    end
    with_options presence: true do
      validates :name
      validates :shipping_category, if: :requires_shipping_category?
      validates :price, if: :requires_price?
    end

    validate :discontinue_on_must_be_later_than_make_active_at, if: -> { make_active_at && discontinue_on }

    scope :for_store, ->(store) { joins(:store_products).where(StoreProduct.table_name => { store_id: store.id }) }
    scope :draft, -> { where(status: 'draft') }
    scope :archived, -> { where(status: 'archived') }
    scope :not_archived, -> { where.not(status: 'archived') }
    scope :on_sale, lambda { |currency = nil|
                      currency ||= Spree::Store.default.default_currency
                      joins(:prices_including_master).with_currency(currency).
                        where.not(spree_prices: { compare_at_amount: [nil, 0] }).
                        where("#{Spree::Price.table_name}.compare_at_amount > #{Spree::Price.table_name}.amount")
                    }

    if defined?(PgSearch)
      scope :multi_search, lambda { |query, include_options = false|
        return none if query.blank?

        product_ids = if Spree.use_translations?
                        Spree::Product::Translation.search_by_name(query).pluck(:spree_product_id)
                      else
                        Spree::Product.search_by_name(query).ids
                      end

        variant_product_ids = if include_options.present?
                                Spree::Variant.search_by_sku_or_options(query).pluck(:product_id)
                              else
                                Spree::Variant.search_by_sku(query).pluck(:product_id)
                              end

        where(id: (product_ids + variant_product_ids).uniq.compact)
      }
    else
      scope :multi_search, lambda { |query|
        return none if query.blank?

        product_ids = Spree::Variant.search_by_product_name_or_sku(query).pluck(:product_id)
        where(id: product_ids.uniq.compact)
      }
    end

    scope :archivable, -> { where(status: %w[active draft]) }
    scope :by_source, ->(source) { send(source) }
    scope :paused, -> { where(status: 'paused') }
    scope :published, -> { where(status: 'active') }
    scope :in_stock_items, -> { joins(:variants).merge(Spree::Variant.in_stock_or_backorderable) }
    scope :out_of_stock_items, lambda {
      joins(variants_including_master: :stock_items).
        where(spree_variants: { track_inventory: true }).
        where.not(id: Spree::Variant.where(track_inventory: false).pluck(:product_id).uniq).
        where(spree_stock_items: { backorderable: false }).
        group(:id).
        having("SUM(#{Spree::StockItem.table_name}.count_on_hand) <= 0")
    }
    scope :out_of_stock, lambda {
                           joins(:stock_items).where("#{Spree::Variant.table_name}.track_inventory = ? OR #{Spree::StockItem.table_name}.count_on_hand <= ?", false, 0)
                         }

    scope :by_best_selling, lambda { |order_direction = :desc|
      left_joins(:orders).
        select("#{Spree::Product.table_name}.*, COUNT(#{Spree::Order.table_name}.id) AS completed_orders_count, SUM(#{Spree::Order.table_name}.total) AS completed_orders_total").
        where(Spree::Order.table_name => { id: nil }).
        or(where.not(Spree::Order.table_name => { completed_at: nil })).
        group("#{Spree::Product.table_name}.id").
        order(completed_orders_count: order_direction, completed_orders_total: order_direction)
    }

    attr_accessor :option_values_hash

    accepts_nested_attributes_for :product_properties, allow_destroy: true, reject_if: lambda { |pp|
                                                                                         pp[:property_id].blank? || (pp[:id].blank? && pp[:value].blank?)
                                                                                       }
    accepts_nested_attributes_for(
      :variants,
      allow_destroy: true,
      reject_if: lambda do |v|
        v[:option_value_variants_attributes].blank? && v[:stock_items_attributes].blank? && v[:prices_attributes].blank?
      end
    )
    accepts_nested_attributes_for :master, reject_if: :all_blank
    accepts_nested_attributes_for(
      :product_option_types,
      allow_destroy: true,
      reject_if: ->(pot) { pot[:option_type_id].blank? || pot[:position].blank? }
    )

    alias options product_option_types

    self.whitelisted_ransackable_attributes = %w[description name slug discontinue_on status]
    self.whitelisted_ransackable_associations = %w[taxons stores variants_including_master master variants tags labels
                                                   shipping_category classifications option_types properties]
    self.whitelisted_ransackable_scopes = %w[not_discontinued search_by_name in_taxon price_between
                                             multi_search in_stock_items out_of_stock_items]

    [
      :sku, :barcode, :weight, :height, :width, :depth, :is_master, :dimensions_unit, :weight_unit
    ].each do |method_name|
      delegate method_name, :"#{method_name}=", to: :find_or_build_master
    end

    [
      :price, :price_in, :amount_in, :compare_at_price, :compare_at_amount_in,
      :currency, :cost_currency, :cost_price, :track_inventory
    ].each do |method_name|
      delegate method_name, :"#{method_name}=", to: :default_variant
    end

    delegate :display_amount, :display_price, :has_default_price?, :track_inventory?,
             :display_compare_at_price, :images, to: :default_variant

    alias master_images images

    state_machine :status, initial: :draft do
      event :activate do
        transition to: :active
      end
      after_transition to: :active, do: [:after_activate, :send_product_activated_webhook]

      event :archive do
        transition to: :archived
      end
      after_transition to: :archived, do: [:after_archive, :send_product_archived_webhook]

      event :draft do
        transition to: :draft
      end
      after_transition to: :draft, do: [:after_draft, :send_product_drafted_webhook]
    end

    def self.bulk_auto_match_taxons(store, product_ids)
      return if store.taxons.automatic.none?

      products_to_auto_match_ids = store.products.not_deleted.not_archived.where(id: product_ids).ids

      # for ActiveJob 7.1+
      if ActiveJob.respond_to?(:perform_all_later)
        auto_match_taxons_jobs = products_to_auto_match_ids.map do |product_id|
          Spree::Products::AutoMatchTaxonsJob.new(product_id)
        end

        ActiveJob.perform_all_later(auto_match_taxons_jobs)
      else
        products_to_auto_match_ids.each { |product_id| Spree::Products::AutoMatchTaxonsJob.perform_later(product_id) }
      end
    end

    # Can't use short form block syntax due to https://github.com/Netflix/fast_jsonapi/issues/259
    def purchasable?
      @purchasable ||= default_variant.purchasable? || variants.in_stock_or_backorderable.any?
    end

    # Can't use short form block syntax due to https://github.com/Netflix/fast_jsonapi/issues/259
    def in_stock?
      @in_stock ||= default_variant.in_stock? || variants.in_stock.any?
    end

    # Can't use short form block syntax due to https://github.com/Netflix/fast_jsonapi/issues/259
    def backorderable?
      default_variant.backorderable? || variants.any?(&:backorderable?)
    end

    def on_sale?(currency)
      prices_including_master.find_all { |p| p.currency == currency }.any?(&:discounted?)
    end

    def find_or_build_master
      master || build_master
    end

    # the master variant is not a member of the variants array
    def has_variants?
      @has_variants ||= variants.loaded? ? variants.size.positive? : variants.any?
    end

    # Returns default Variant for Product
    # If `track_inventory_levels` is enabled it will try to find the first Variant
    # in stock or backorderable, if there's none it will return first Variant sorted
    # by `position` attribute
    # If `track_inventory_levels` is disabled it will return first Variant sorted
    # by `position` attribute
    #
    # @return [Spree::Variant]
    def default_variant
      @default_variant ||= if Spree::Config[:track_inventory_levels] && available_variant = variants.detect(&:purchasable?)
                             available_variant
                           else
                             has_variants? ? variants.first : find_or_build_master
                           end
    end

    # Returns default Variant ID for Product
    # @return [Integer]
    def default_variant_id
      @default_variant_id ||= default_variant.id
    end

    # Returns default Image for Product
    # @return [Spree::Image]
    def default_image
      @default_image ||= if images.any?
                           images.first
                         elsif default_variant.images.any?
                           default_variant.default_image
                         elsif variant_images.any?
                           variant_images.first
                         end
    end
    alias featured_image default_image

    # Returns secondary Image for Product
    # @return [Spree::Image]
    def secondary_image
      @secondary_image ||= if images.size > 1
                             images.second
                           elsif images.size == 1 && default_variant.images.size.positive?
                             default_variant.images.first
                           elsif default_variant.images.size > 1
                             default_variant.secondary_image
                           elsif variant_images.size > 1
                             variant_images.second
                           end
    end

    # Returns the short description for the product
    # @return [String]
    def storefront_description
      property('short_description') || description
    end

    # Returns tax category for Product
    # @return [Spree::TaxCategory, nil]
    def tax_category
      @tax_category ||= super || TaxCategory.default
    end

    # Adding properties and option types on creation based on a chosen prototype
    attr_accessor :prototype_id

    def first_or_default_variant(currency)
      if !has_variants?
        default_variant
      elsif first_available_variant(currency).present?
        first_available_variant(currency)
      else
        variants.first
      end
    end

    def first_available_variant(currency)
      variants.find { |v| v.purchasable? && v.price_in(currency).amount.present? }
    end

    def price_varies?(currency)
      prices_including_master.find_all { |p| p.currency == currency && p.amount.present? }.map(&:amount).uniq.count > 1
    end

    def any_variant_available?(currency)
      if has_variants?
        first_available_variant(currency).present?
      else
        master.purchasable? && master.price_in(currency).amount.present?
      end
    end

    # returns the lowest price for the product in the given currency
    # prices_including_master are usually already loaded, so this should not trigger an extra query
    def lowest_price(currency)
      prices_including_master.find_all { |p| p.currency == currency }.min_by(&:amount)
    end

    # Ensures option_types and product_option_types exist for keys in option_values_hash
    def ensure_option_types_exist_for_values_hash
      return if option_values_hash.nil?

      # we need to convert the keys to string to make it work with UUIDs
      required_option_type_ids = option_values_hash.keys.map(&:to_s)
      missing_option_type_ids = required_option_type_ids - option_type_ids.map(&:to_s)
      missing_option_type_ids.each do |id|
        product_option_types.create(option_type_id: id)
      end
    end

    # for adding products which are closely related to existing ones
    # define "duplicate_extra" for site-specific actions, eg for additional fields
    def duplicate
      Products::Duplicator.call(product: self)
    end

    # use deleted? rather than checking the attribute directly. this
    # allows extensions to override deleted? if they want to provide
    # their own definition.
    def deleted?
      !!deleted_at
    end

    # determine if product is available.
    # deleted products and products with status different than active
    # are not available
    def available?
      active? && !deleted? && (available_on.nil? || available_on <= Time.current)
    end

    def discontinue!
      self.discontinue_on = Time.current
      self.status = 'archived'
      save(validate: false)
    end

    def discontinued?
      !!discontinue_on && discontinue_on <= Time.current
    end

    # determine if any variant (including master) can be supplied
    def can_supply?
      variants_including_master.any?(&:can_supply?)
    end

    # determine if any variant (including master) is out of stock and backorderable
    def backordered?
      variants_including_master.any?(&:backordered?)
    end

    # split variants list into hash which shows mapping of opt value onto matching variants
    # eg categorise_variants_from_option(color) => {"red" -> [...], "blue" -> [...]}
    def categorise_variants_from_option(opt_type)
      return {} unless option_types.include?(opt_type)

      variants.active.group_by { |v| v.option_values.detect { |o| o.option_type == opt_type } }
    end

    def self.like_any(fields, values)
      conditions = fields.product(values).map do |(field, value)|
        arel_table[field].matches("%#{value}%")
      end
      where conditions.inject(:or)
    end

    # Suitable for displaying only variants that has at least one option value.
    # There may be scenarios where an option type is removed and along with it
    # all option values. At that point all variants associated with only those
    # values should not be displayed to frontend users. Otherwise it breaks the
    # idea of having variants
    def variants_and_option_values(current_currency = nil)
      variants.active(current_currency).joins(:option_value_variants)
    end

    def empty_option_values?
      options.empty? || options.any? do |opt|
        opt.option_type.option_values.empty?
      end
    end

    def property(property_name)
      if product_properties.loaded?
        product_properties.detect { |property| property.property.name == property_name }.try(:value)
      else
        product_properties.joins(:property).find_by(spree_properties: { name: property_name }).try(:value)
      end
    end

    def set_property(property_name, property_value, property_presentation = property_name)
      property_name = property_name.to_s.parameterize
      ApplicationRecord.transaction do
        # Manual first_or_create to work around Mobility bug
        property = if Property.where(name: property_name).exists?
                     existing_property = Property.where(name: property_name).first
                     existing_property.presentation ||= property_presentation
                     existing_property.save
                     existing_property
                   else
                     Property.create(name: property_name, presentation: property_presentation)
                   end

        product_property = if ProductProperty.where(product: self, property: property).exists?
                             ProductProperty.where(product: self, property: property).first
                           else
                             ProductProperty.new(product: self, property: property)
                           end

        product_property.value = property_value
        product_property.save!
      end
    end

    def remove_property(property_name)
      product_properties.joins(:property).find_by(spree_properties: { name: property_name.parameterize })&.destroy
    end

    def total_on_hand
      @total_on_hand ||= if any_variants_not_track_inventory?
                           BigDecimal::INFINITY
                         else
                           stock_items.loaded? ? stock_items.sum(&:count_on_hand) : stock_items.sum(:count_on_hand)
                         end
    end

    # Master variant may be deleted (i.e. when the product is deleted)
    # which would make AR's default finder return nil.
    # This is a stopgap for that little problem.
    def master
      super || variants_including_master.with_deleted.find_by(is_master: true)
    end

    # Returns the brand for the product
    # If a brand association is defined (e.g., belongs_to :brand), it will be used
    # Otherwise, falls back to brand_taxon for compatibility
    # @return [Spree::Brand, Spree::Taxon]
    def brand
      if self.class.reflect_on_association(:brand)
        super
      else
        Spree::Deprecation.warn('Spree::Product#brand is deprecated and will be removed in Spree 6. Please use Spree::Product#brand_taxon instead.')
        brand_taxon
      end
    end

    # Returns the brand taxon for the product
    # @return [Spree::Taxon]
    def brand_taxon
      @brand ||= if Spree.use_translations?
                   taxons.joins(:taxonomy).
                     join_translation_table(Taxonomy).
                     find_by(Taxonomy.translation_table_alias => { name: Spree.t(:taxonomy_brands_name) })
                 else
                   if taxons.loaded?
                     taxons.find { |taxon| taxon.taxonomy.name == Spree.t(:taxonomy_brands_name) }
                   else
                     taxons.joins(:taxonomy).find_by(Taxonomy.table_name => { name: Spree.t(:taxonomy_brands_name) })
                   end
                 end
    end

    # Returns the brand name for the product
    # @return [String]
    def brand_name
      brand&.name
    end

    # Returns the category for the product
    # If a category association is defined (e.g., belongs_to :category), it will be used
    # Otherwise, falls back to category_taxon for compatibility
    # @return [Spree::Category, Spree::Taxon]
    def category
      if self.class.reflect_on_association(:category)
        super
      else
        Spree::Deprecation.warn('Spree::Product#category is deprecated and will be removed in Spree 6. Please use Spree::Product#category_taxon instead.')
        category_taxon
      end
    end

    # Returns the category taxon for the product
    # @return [Spree::Taxon]
    def category_taxon
      @category ||= if Spree.use_translations?
                      taxons.joins(:taxonomy).
                        join_translation_table(Taxonomy).
                        order(depth: :desc).
                        find_by(Taxonomy.translation_table_alias => { name: Spree.t(:taxonomy_categories_name) })
                    else
                      if taxons.loaded?
                        taxons.find { |taxon| taxon.taxonomy.name == Spree.t(:taxonomy_categories_name) }
                      else
                        taxons.joins(:taxonomy).order(depth: :desc).find_by(Taxonomy.table_name => { name: Spree.t(:taxonomy_categories_name) })
                      end
                    end
    end

    def main_taxon
      category_taxon || taxons.first
    end

    def taxons_for_store(store)
      Rails.cache.fetch("#{cache_key_with_version}/taxons-per-store/#{store.id}") do
        taxons.for_store(store)
      end
    end

    def any_variant_in_stock_or_backorderable?
      if has_variants?
        variants_including_master.in_stock_or_backorderable.exists?
      else
        master.in_stock_or_backorderable?
      end
    end

    # Check if the product is digital by checking if any of its shipping methods are digital delivery
    # This is used to determine if the product is digital and should have a digital delivery price
    # instead of a physical shipping price
    #
    # @return [Boolean]
    def digital?
      @digital ||= shipping_methods&.digital&.exists?
    end

    def auto_match_taxons
      return if deleted?
      return if archived?

      store = stores.find_by(default: true) || stores.first
      return if store.nil? || store.taxons.automatic.none?

      Spree::Products::AutoMatchTaxonsJob.perform_later(id)
    end

    def to_csv(store = nil)
      store ||= stores.default || stores.first
      properties_for_csv = if Spree::Config[:product_properties_enabled]
        Spree::Property.order(:position).flat_map do |property|
          [
            property.name,
            product_properties.find { |pp| pp.property_id == property.id }&.value
          ]
        end
      else
        []
      end
      metafields_for_csv ||= Spree::MetafieldDefinition.for_resource_type('Spree::Product').order(:namespace, :key).map do |mf_def|
        metafields.find { |mf| mf.metafield_definition_id == mf_def.id }&.csv_value
      end
      taxons_for_csv ||= taxons.manual.reorder(depth: :desc).first(3).pluck(:pretty_name)
      taxons_for_csv.fill(nil, taxons_for_csv.size...3)

      csv_lines = []

      if has_variants?
        variants_including_master.each_with_index do |variant, index|
          csv_lines << Spree::CSV::ProductVariantPresenter.new(self, variant, index, properties_for_csv, taxons_for_csv, store, metafields_for_csv).call
        end
      else
        csv_lines << Spree::CSV::ProductVariantPresenter.new(self, master, 0, properties_for_csv, taxons_for_csv, store, metafields_for_csv).call
      end

      csv_lines
    end

    def page_builder_url
      return unless Spree::Core::Engine.routes.url_helpers.respond_to?(:product_path)

      Spree::Core::Engine.routes.url_helpers.product_path(self)
    end

    private

    def add_associations_from_prototype
      if prototype_id && prototype = Spree::Prototype.find_by(id: prototype_id)
        prototype.properties.each do |property|
          product_properties.create(property: property, value: 'Placeholder')
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
        variants.create(
          option_value_ids: ids,
          price: master.price
        )
      end
      save
    end

    def default_variant_cache_key
      Spree::Deprecation.warn('Spree::Product#default_variant_cache_key is deprecated and will be removed in Spree 6. Please remove any occurrences of it.')

      "spree/default-variant/#{cache_key_with_version}/#{Spree::Config[:track_inventory_levels]}"
    end

    def ensure_master
      return unless new_record?

      self.master ||= build_master
    end

    def assign_default_tax_category
      self.tax_category = Spree::TaxCategory.default if new_record?
    end

    def anything_changed?
      saved_changes? || @nested_changes
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
        master.errors.map { |error| { field: error.attribute, message: error&.message } }.each do |err|
          next if err[:field].blank? || err[:message].blank?

          errors.add(err[:field], err[:message])
        end
      end
    end

    def ensure_default_shipping_category
      return if shipping_category.present?

      if new_record?
        name = I18n.t('spree.seed.shipping.categories.default')
        self.shipping_category = Spree::ShippingCategory.find_or_create_by!(name: name)
      end
    end

    def run_touch_callbacks
      run_callbacks(:touch)
    end

    def taxon_and_ancestors
      @taxon_and_ancestors ||= taxons.map(&:self_and_ancestors).flatten.uniq
    end

    # Iterate through this products taxons and taxonomies and touch their timestamps in a batch
    def touch_taxons
      if taxons.any?
        Spree::Products::TouchTaxonsJob.
          set(wait: 5.seconds).
          perform_later(taxon_and_ancestors.map(&:id), taxonomy_ids.uniq)
      end
    end

    def ensure_not_in_complete_orders
      if orders.complete.any?
        errors.add(:base, :cannot_destroy_if_attached_to_line_items)
        throw(:abort)
      end
    end

    def remove_taxon(taxon)
      removed_classifications = classifications.where(taxon: taxon)
      removed_classifications.each(&:remove_from_list)
    end

    def discontinue_on_must_be_later_than_make_active_at
      if discontinue_on < make_active_at
        errors.add(:discontinue_on, :invalid_date_range)
      end
    end

    def requires_price?
      Spree::Config[:require_master_price]
    end

    def requires_shipping_category?
      true
    end

    def eligible_for_taxon_matching?
      previously_new_record? || tag_list_previously_changed? || available_on_previously_changed?
    end

    def after_activate
      # Implement your logic here
    end

    def after_archive
      # Implement your logic here
    end

    def after_draft
      # Implement your logic here
    end
  end
end
