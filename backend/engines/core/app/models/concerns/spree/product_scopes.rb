module Spree
  module ProductScopes
    extend ActiveSupport::Concern

    included do
      cattr_accessor :search_scopes do
        []
      end

      def self.add_search_scope(name, &block)
        singleton_class.send(:define_method, name.to_sym, &block)
        search_scopes << name.to_sym
      end

      def self.simple_scopes
        [
          :ascend_by_updated_at,
          :descend_by_updated_at,
          :ascend_by_name,
          :descend_by_name
        ]
      end

      def self.add_simple_scopes(scopes)
        scopes.each do |name|
          # We should not define price scopes here, as they require something slightly different
          next if name.to_s.include?('master_price')

          parts = name.to_s.match(/(.*)_by_(.*)/)
          scope(name.to_s, -> { order(Arel.sql(sanitize_sql("#{Product.quoted_table_name}.#{parts[2]} #{parts[1] == 'ascend' ? 'ASC' : 'DESC'}"))) })
        end
      end

      def self.property_conditions(property)
        properties_table = Property.table_name

        case property
        when Property then { "#{properties_table}.id" => property.id }
        when Integer  then { "#{properties_table}.id" => property }
        else
          if Property.column_for_attribute('id').type == :uuid
            ["#{properties_table}.name = ? OR #{properties_table}.id = ?", property, property]
          else
            { "#{properties_table}.name" => property }
          end
        end
      end

      add_simple_scopes simple_scopes

      add_search_scope :ascend_by_master_price do
        order(price_table_name => { amount: :asc })
      end

      add_search_scope :descend_by_master_price do
        order(price_table_name => { amount: :desc })
      end

      # Price sorting scopes that use subqueries to get prices across all variants
      # These ensure products with only variant prices (no master price) are included in results
      add_search_scope :ascend_by_price do
        price_subquery = Price
          .non_zero
          .joins(:variant)
          .where("#{Variant.table_name}.product_id = #{Product.table_name}.id")
          .select('MIN(amount)')

        price_sort_sql = "COALESCE((#{price_subquery.to_sql}), 999999999)"

        select("#{Product.table_name}.*", "#{price_sort_sql} AS min_price").
          order(Arel.sql("#{price_sort_sql} ASC"))
      end

      add_search_scope :descend_by_price do
        price_subquery = Price
          .non_zero
          .joins(:variant)
          .where("#{Variant.table_name}.product_id = #{Product.table_name}.id")
          .select('MAX(amount)')

        price_sort_sql = "COALESCE((#{price_subquery.to_sql}), 0)"

        select("#{Product.table_name}.*", "#{price_sort_sql} AS max_price").
          order(Arel.sql("#{price_sort_sql} DESC"))
      end

      add_search_scope :price_between do |low, high|
        where(Price.table_name => { amount: low..high })
      end

      add_search_scope :master_price_lte do |price|
        where(Price.table_name => { amount: ..price })
      end

      add_search_scope :master_price_gte do |price|
        where(Price.table_name => { amount: price.. })
      end

      add_search_scope :in_stock do
        joins(:variants_including_master).merge(Spree::Variant.in_stock)
      end

      add_search_scope :backorderable do
        joins(:variants_including_master).merge(Spree::Variant.backorderable)
      end

      add_search_scope :in_stock_or_backorderable do
        joins(:variants_including_master).merge(Spree::Variant.in_stock_or_backorderable)
      end

      # This scope selects products in taxon AND all its descendants
      # If you need products only within one taxon use
      #
      #   Spree::Product.joins(:taxons).where(Taxon.table_name => { id: taxon.id })
      #
      # If you're using count on the result of this scope, you must use the
      # `:distinct` option as well:
      #
      #   Spree::Product.in_taxon(taxon).count(distinct: true)
      #
      # This is so that the count query is distinct'd:
      #
      #   SELECT COUNT(DISTINCT "spree_products"."id") ...
      #
      #   vs.
      #
      #   SELECT COUNT(*) ...
      add_search_scope :in_taxon do |taxon|
        joins(:classifications).
          where("#{Classification.table_name}.taxon_id" => taxon.cached_self_and_descendants_ids).distinct
      end

      # This scope selects products in all taxons AND all its descendants
      # If you need products only within one taxon use
      #
      #   Spree::Product.taxons_id_eq([x,y])
      add_search_scope :in_taxons do |*taxons|
        taxons = get_taxons(taxons)
        taxons.first ? prepare_taxon_conditions(taxons) : where(nil)
      end

      add_search_scope :ascend_by_taxons_min_position do |taxon_ids|
        min_position_sql = "MIN(#{Classification.table_name}.position)"

        joins(:classifications).
          where(Classification.table_name => { taxon_id: taxon_ids }).
          select("#{Product.table_name}.*", "#{min_position_sql} AS min_taxon_position").
          group("#{Product.table_name}.id").
          order(Arel.sql("#{min_position_sql} ASC"))
      end

      # a scope that finds all products having property specified by name, object or id
      add_search_scope :with_property do |property|
        joins(:properties).where(property_conditions(property))
      end

      # a simple test for product with a certain property-value pairing
      # note that it can test for properties with NULL values, but not for absent values
      add_search_scope :with_property_value do |property, value|
        if Spree.use_translations?
          joins(:properties).
            join_translation_table(Property).
            join_translation_table(ProductProperty).
            where(ProductProperty.translation_table_alias => { value: value }).
            where(property_conditions(property))
        else
          joins(:properties).
            where(ProductProperty.table_name => { value: value }).
            where(property_conditions(property))
        end
      end

      add_search_scope :with_property_values do |property_filter_param, property_values|
        joins(product_properties: :property).
          where(Property.table_name => { filter_param: property_filter_param }).
          where(ProductProperty.table_name => { filter_param: property_values.map(&:parameterize) })
      end

      add_search_scope :with_option do |option|
        if option.is_a?(OptionType)
          joins(:option_types).where(spree_option_types: { id: option.id })
        elsif option.is_a?(Integer)
          joins(:option_types).where(spree_option_types: { id: option })
        elsif OptionType.column_for_attribute('id').type == :uuid
          joins(:option_types).where(spree_option_types: { name: option }).or(Product.joins(:option_types).where(spree_option_types: { id: option }))
        else
          joins(:option_types).where(OptionType.table_name => { name: option })
        end
      end

      add_search_scope :with_option_value do |option, value|
        option_type_id = case option
                         when OptionType then option.id
                         when Integer then option
                         else
                           if OptionType.column_for_attribute('id').type == :uuid
                             OptionType.where(id: option).or(OptionType.where(name: option))&.first&.id
                           else
                             OptionType.where(name: option)&.first&.id
                             OptionType.where(name: option)&.first&.id
                           end
                         end

        return Product.group("#{Spree::Product.table_name}.id").none if option_type_id.blank?

        group("#{Spree::Product.table_name}.id").
          joins(variants: :option_values).
          where(Spree::OptionValue.table_name => { name: value, option_type_id: option_type_id })
      end

      # Filters products by option value IDs (prefix IDs like 'optval_xxx')
      # Accepts an array of option value IDs
      add_search_scope :with_option_value_ids do |*ids|
        ids = ids.flatten.compact
        return none if ids.empty?

        # Handle prefixed IDs (optval_xxx) by decoding to actual IDs
        actual_ids = ids.map do |id|
          id.to_s.include?('_') ? OptionValue.decode_prefixed_id(id) : id
        end.compact

        return none if actual_ids.empty?

        group("#{Spree::Product.table_name}.id").
          joins(variants: :option_values).
          where(Spree::OptionValue.table_name => { id: actual_ids })
      end

      # Finds all products which have either:
      # 1) have an option value with the name matching the one given
      # 2) have a product property with a value matching the one given
      add_search_scope :with do |value|
        includes(variants: :option_values).
          includes(:product_properties).
          where("#{OptionValue.table_name}.name = ? OR #{ProductProperty.table_name}.value = ?", value, value)
      end

      # Finds all products that have a name containing the given words.
      add_search_scope :in_name do |words|
        like_any([:name], prepare_words(words))
      end

      # Finds all products that have a name or meta_keywords containing the given words.
      add_search_scope :in_name_or_keywords do |words|
        like_any([:name, :meta_keywords], prepare_words(words))
      end

      # Finds all products that have a name, description, meta_description or meta_keywords containing the given keywords.
      add_search_scope :in_name_or_description do |words|
        like_any([:name, :description, :meta_description, :meta_keywords], prepare_words(words))
      end

      # Finds all products that have the ids matching the given collection of ids.
      # Alternatively, you could use find(collection_of_ids), but that would raise an exception if one product couldn't be found
      add_search_scope :with_ids do |*ids|
        where(id: ids)
      end

      # Sorts products from most popular (popularity is extracted from how many
      # times use has put product in cart, not completed orders)
      #
      # there is alternative faster and more elegant solution, it has small drawback though,
      # it doesn stack with other scopes :/
      #
      # joins: "LEFT OUTER JOIN (SELECT line_items.variant_id as vid, COUNT(*) as cnt FROM line_items GROUP BY line_items.variant_id) AS popularity_count ON variants.id = vid",
      # order: 'COALESCE(cnt, 0) DESC'
      add_search_scope :descend_by_popularity do
        joins(:master).
          order(%Q{
             COALESCE((
               SELECT
                 COUNT(#{LineItem.quoted_table_name}.id)
               FROM
                 #{LineItem.quoted_table_name}
               JOIN
                 #{Variant.quoted_table_name} AS popular_variants
               ON
                 popular_variants.id = #{LineItem.quoted_table_name}.variant_id
               WHERE
                 popular_variants.product_id = #{Product.quoted_table_name}.id
             ), 0) DESC
          })
      end

      add_search_scope :not_deleted do
        where("#{Product.quoted_table_name}.deleted_at IS NULL or #{Product.quoted_table_name}.deleted_at >= ?", Time.zone.now)
      end

      def self.not_discontinued(only_not_discontinued = true)
        if only_not_discontinued != '0' && only_not_discontinued
          where(discontinue_on: [nil, Time.current..])
        else
          all
        end
      end
      search_scopes << :not_discontinued

      def self.with_currency(currency)
        joins(variants_including_master: :prices).
          where(Price.table_name => { currency: currency.upcase }).
          where.not(Price.table_name => { amount: nil }).
          distinct
      end
      search_scopes << :with_currency

      # Can't use add_search_scope for this as it needs a default argument
      def self.available(available_on = nil, currency = nil)
        scope = not_discontinued.where(status: 'active')
        scope = scope.where("#{Product.quoted_table_name}.available_on <= ?", available_on) if available_on

        unless Spree::Config.show_products_without_price
          currency ||= Spree::Store.default.default_currency
          scope = scope.with_currency(currency)
        end

        scope
      end
      search_scopes << :available

      def self.active(currency = nil)
        available(nil, currency)
      end
      search_scopes << :active

      def self.for_filters(currency, taxon: nil)
        scope = active(currency)
        scope = scope.in_taxon(taxon) if taxon.present?
        scope
      end
      search_scopes << :for_filters

      def self.for_user(user = nil)
        if user.try(:has_spree_role?, 'admin')
          with_deleted
        else
          not_deleted.where(status: 'active')
        end
      end

      add_search_scope :taxons_name_eq do |name|
        group('spree_products.id').joins(:taxons).where(Taxon.arel_table[:name].eq(name))
      end

      # Orders products by best selling based on units_sold_count and revenue
      # stored in spree_products_stores table.
      #
      # These metrics are updated asynchronously when orders are completed
      # via the ProductMetricsSubscriber.
      #
      # @param order_direction [Symbol] :desc (default) or :asc
      # @return [ActiveRecord::Relation]
      add_search_scope :by_best_selling do |order_direction = :desc|
        store_id = Spree::Current.store&.id
        sp_table = StoreProduct.arel_table
        products_table = Product.arel_table

        conditions = sp_table[:product_id].eq(products_table[:id]).and(sp_table[:store_id].eq(store_id))

        units_sold = Arel::Nodes::NamedFunction.new('COALESCE', [sp_table.project(sp_table[:units_sold_count]).where(conditions), 0])
        revenue = Arel::Nodes::NamedFunction.new('COALESCE', [sp_table.project(sp_table[:revenue]).where(conditions), 0])

        order_dir = order_direction == :desc ? :desc : :asc
        order(units_sold.send(order_dir)).order(revenue.send(order_dir))
      end

      # .search_by_name
      if defined?(PgSearch)
        include PgSearch::Model

        pg_search_scope :search_by_name, against: { name: 'A', meta_title: 'B' }, using: { trigram: { threshold: 0.3, word_similarity: true } }
      else
        def self.search_by_name(query)
          i18n { name.lower.matches("%#{query.downcase}%") }
        end
      end
      search_scopes << :search_by_name

      def self.price_table_name
        Price.quoted_table_name
      end
      private_class_method :price_table_name

      # specifically avoid having an order for taxon search (conflicts with main order)
      def self.prepare_taxon_conditions(taxons)
        ids = taxons.map(&:cached_self_and_descendants_ids).flatten.uniq
        joins(:classifications).where(Classification.table_name => { taxon_id: ids })
      end
      private_class_method :prepare_taxon_conditions

      # Produce an array of keywords for use in scopes.
      # Always return array with at least an empty string to avoid SQL errors
      def self.prepare_words(words)
        return [''] if words.blank?

        a = words.split(/[,\s]/).map(&:strip)
        a.any? ? a : ['']
      end
      private_class_method :prepare_words

      def self.get_taxons(*ids_or_records_or_names)
        ids_or_records_or_names.flatten.map do |t|
          case t
          when ApplicationRecord then t
          else
            Taxon.where(name: t).
              or(Taxon.where(Taxon.arel_table[:id].eq(t))).
              or(Taxon.where(Taxon.arel_table[:permalink].matches("%/#{t}/"))).
              or(Taxon.where(Taxon.arel_table[:permalink].matches("#{t}/"))).first
          end
        end.compact.flatten.uniq
      end
      private_class_method :get_taxons
    end
  end
end
