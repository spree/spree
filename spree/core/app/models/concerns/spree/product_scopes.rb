module Spree
  module ProductScopes
    extend ActiveSupport::Concern

    included do
      cattr_accessor :search_scopes do
        []
      end

      def self.add_search_scope(name, &block)
        Spree::Deprecation.warn("add_search_scope is deprecated and will be removed in Spree 6.0. Use scope :#{name}, &block instead or use method instead")
        singleton_class.send(:define_method, name.to_sym, &block)
        search_scopes << name.to_sym
      end

      scope :ascend_by_updated_at, -> { order("#{Product.quoted_table_name}.updated_at ASC") }
      scope :descend_by_updated_at, -> { order("#{Product.quoted_table_name}.updated_at DESC") }
      scope :ascend_by_name, -> { order("#{Product.quoted_table_name}.name ASC") }
      scope :descend_by_name, -> { order("#{Product.quoted_table_name}.name DESC") }

      # Deprecated — master variant being removed in 6.0. Use ascend_by_price / descend_by_price instead.
      def self.ascend_by_master_price
        Spree::Deprecation.warn('ascend_by_master_price is deprecated and will be removed in Spree 6.0. Use ascend_by_price instead.')
        order(price_table_name => { amount: :asc })
      end

      # Deprecated — master variant being removed in 6.0. Use ascend_by_price / descend_by_price instead.
      def self.descend_by_master_price
        Spree::Deprecation.warn('descend_by_master_price is deprecated and will be removed in Spree 6.0. Use descend_by_price instead.')
        order(price_table_name => { amount: :desc })
      end

      # Price sorting scopes that use a derived table JOIN to get prices across all variants.
      # These ensure products with only variant prices (no master price) are included in results.
      #
      # Uses Arel::Nodes::As for select expressions so that:
      # - PG allows ORDER BY with DISTINCT (expressions must appear in SELECT list)
      # - Mobility's select_for_count can safely call .right on all select_values
      scope :ascend_by_price, -> {
        price_agg_sql = Price.non_zero.joins(:variant)
                            .select("#{Variant.table_name}.product_id AS product_id, MIN(#{Price.table_name}.amount) AS agg_price")
                            .group("#{Variant.table_name}.product_id")
                            .to_sql

        price_expr = Arel.sql('COALESCE(price_agg.agg_price, 999999999)')

        joins("LEFT JOIN (#{price_agg_sql}) AS price_agg ON price_agg.product_id = #{Product.table_name}.id").
          select("#{Product.table_name}.*").
          select(Arel::Nodes::As.new(price_expr, Arel.sql('min_price'))).
          order(price_expr.asc)
      }

      scope :descend_by_price, -> {
        price_agg_sql = Price.non_zero.joins(:variant)
                            .select("#{Variant.table_name}.product_id AS product_id, MAX(#{Price.table_name}.amount) AS agg_price")
                            .group("#{Variant.table_name}.product_id")
                            .to_sql

        price_expr = Arel.sql('COALESCE(price_agg.agg_price, 0)')

        joins("LEFT JOIN (#{price_agg_sql}) AS price_agg ON price_agg.product_id = #{Product.table_name}.id").
          select("#{Product.table_name}.*").
          select(Arel::Nodes::As.new(price_expr, Arel.sql('max_price'))).
          order(price_expr.desc)
      }

      scope :price_between, ->(low, high) {
        where(Price.table_name => { amount: low..high })
      }

      # Deprecated — master variant being removed in 6.0. Use price_lte / price_gte instead.
      def self.master_price_lte(price)
        Spree::Deprecation.warn('master_price_lte is deprecated and will be removed in Spree 6.0. Use price_lte instead.')
        where(Price.table_name => { amount: ..price })
      end

      # Deprecated — master variant being removed in 6.0. Use price_lte / price_gte instead.
      def self.master_price_gte(price)
        Spree::Deprecation.warn('master_price_gte is deprecated and will be removed in Spree 6.0. Use price_gte instead.')
        where(Price.table_name => { amount: price.. })
      end

      # Joins spree_variants and spree_stock_items directly (without association
      # aliases) so that the table names stay as-is. This avoids alias conflicts
      # when combined with other scopes (e.g., price sorting) that also join
      # spree_variants through associations which generate aliases.
      def self.join_variants_and_stock_items
        joins("INNER JOIN #{Variant.table_name} ON #{Variant.table_name}.deleted_at IS NULL AND #{Variant.table_name}.product_id = #{Product.table_name}.id").
          joins("LEFT OUTER JOIN #{StockItem.table_name} ON #{StockItem.table_name}.deleted_at IS NULL AND #{StockItem.table_name}.variant_id = #{Variant.table_name}.id")
      end
      private_class_method :join_variants_and_stock_items

      # Mirrors Spree::Variant.in_stock_or_backorderable logic using raw table
      # names (to pair with join_variants_and_stock_items).
      scope :in_stock_or_backorderable_condition, -> {
        where(
          "#{Variant.table_name}.track_inventory = ? OR #{StockItem.table_name}.count_on_hand > ? OR #{StockItem.table_name}.backorderable = ?",
          false, 0, true
        )
      }

      # Ransack calls with '1' to activate, '0' or nil to skip
      # In Ruby code: in_stock(true) for in-stock, in_stock(false) for out-of-stock
      def self.in_stock(in_stock = true)
        if in_stock == '0' || !in_stock
          all
        else
          join_variants_and_stock_items.in_stock_or_backorderable_condition
        end
      end

      scope :price_lte, ->(price) {
        where(Price.table_name => { amount: ..price })
      }

      scope :price_gte, ->(price) {
        where(Price.table_name => { amount: price.. })
      }

      def self.out_of_stock(out_of_stock = true)
        if out_of_stock == '0' || !out_of_stock
          all
        else
          where.not(id: join_variants_and_stock_items.in_stock_or_backorderable_condition)
        end
      end

      def self.backorderable
        join_variants_and_stock_items.where(StockItem.table_name => { backorderable: true })
      end

      def self.in_stock_or_backorderable
        join_variants_and_stock_items.in_stock_or_backorderable_condition
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
      scope :in_taxon, ->(taxon) {
        joins(:classifications).
          where("#{Classification.table_name}.taxon_id" => taxon.cached_self_and_descendants_ids).distinct
      }

      # Products in a category AND all its descendants.
      # Accepts a Category record or a prefixed ID string (e.g. 'ctg_xxx').
      def self.in_category(category_or_id)
        category = category_or_id.is_a?(String) ? Spree::Taxon.find_by_prefix_id(category_or_id) : category_or_id
        return none unless category

        in_taxon(category)
      end

      # Products in ANY of the given categories (OR logic), each including descendants.
      # Accepts an array of Category records, prefixed ID strings, or a mix.
      def self.in_categories(*categories_or_ids)
        categories_or_ids = categories_or_ids.flatten.compact
        return none if categories_or_ids.empty?

        ids, records = categories_or_ids.partition { |c| c.is_a?(String) }
        if ids.any?
          decoded = ids.filter_map { |id| Spree::Taxon.decode_prefixed_id(id) }
          records += Spree::Taxon.where(id: decoded).to_a if decoded.any?
        end
        return none if records.empty?

        taxon_ids = records.flat_map(&:cached_self_and_descendants_ids).uniq

        joins(:classifications).where(Classification.table_name => { taxon_id: taxon_ids }).distinct
      end

      # Deprecated — remove in 6.0. Use in_taxon instead.
      def self.in_taxons(*taxons)
        Spree::Deprecation.warn('in_taxons is deprecated and will be removed in Spree 6.0. Use in_taxon instead.')
        taxons = get_taxons(taxons)
        taxons.first ? prepare_taxon_conditions(taxons) : where(nil)
      end

      scope :ascend_by_taxons_min_position, ->(taxon_ids) {
        min_position_sql = "MIN(#{Classification.table_name}.position)"

        joins(:classifications).
          where(Classification.table_name => { taxon_id: taxon_ids }).
          select("#{Product.table_name}.*", "#{min_position_sql} AS min_taxon_position").
          group("#{Product.table_name}.id").
          order(Arel.sql("#{min_position_sql} ASC"))
      }

      # Deprecated — remove in 6.0. Not used internally.
      def self.with_option(option)
        Spree::Deprecation.warn('with_option is deprecated and will be removed in Spree 6.0.')
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

      scope :with_option_value, ->(option, value) {
        option_type_id = case option
                         when OptionType then option.id
                         when Integer then option
                         else
                           if OptionType.column_for_attribute('id').type == :uuid
                             OptionType.where(id: option).or(OptionType.where(name: option))&.first&.id
                           else
                             OptionType.where(name: option)&.first&.id
                           end
                         end

        next Product.group("#{Spree::Product.table_name}.id").none if option_type_id.blank?

        group("#{Spree::Product.table_name}.id").
          joins(variants: :option_values).
          where(Spree::OptionValue.table_name => { name: value, option_type_id: option_type_id })
      }

      # Filters products by option value IDs (prefix IDs like 'optval_xxx').
      # Groups values by option type automatically:
      #   - Within the same option type: OR (Blue OR Red)
      #   - Across different option types: AND ((Blue OR Red) AND (S OR M))
      def self.with_option_value_ids(*ids)
        ids = ids.flatten.compact
        return none if ids.empty?

        actual_ids = ids.map { |id| id.to_s.include?('_') ? OptionValue.decode_prefixed_id(id) : id }.compact
        return none if actual_ids.empty?

        grouped = OptionValue.where(id: actual_ids).group_by(&:option_type_id)
        return none if grouped.empty?

        scope = all
        grouped.each_value do |option_values|
          ov_ids = option_values.map(&:id)
          matching_product_ids = Variant.where(deleted_at: nil)
                                       .joins(:option_value_variants)
                                       .where(OptionValueVariant.table_name => { option_value_id: ov_ids })
                                       .select(:product_id)
          scope = scope.where(id: matching_product_ids)
        end
        scope
      end

      # Deprecated — remove in 6.0. Not used internally.
      def self.with(value)
        Spree::Deprecation.warn('Product.with is deprecated and will be removed in Spree 6.0.')
        includes(variants: :option_values).
          where("#{OptionValue.table_name}.name = ?", value)
      end

      # Deprecated — remove in 6.0. Use .search scope instead.
      def self.in_name(words)
        Spree::Deprecation.warn('in_name is deprecated and will be removed in Spree 6.0. Use .search instead.')
        like_any([:name], prepare_words(words))
      end

      # Deprecated — remove in 6.0. Use .search scope instead.
      def self.in_name_or_keywords(words)
        Spree::Deprecation.warn('in_name_or_keywords is deprecated and will be removed in Spree 6.0. Use .search instead.')
        like_any([:name, :meta_keywords], prepare_words(words))
      end

      # Deprecated — remove in 6.0. Use .search scope instead.
      def self.in_name_or_description(words)
        Spree::Deprecation.warn('in_name_or_description is deprecated and will be removed in Spree 6.0. Use .search instead.')
        like_any([:name, :description, :meta_description, :meta_keywords], prepare_words(words))
      end

      # Deprecated — remove in 6.0. Use where(id: ids) directly.
      def self.with_ids(*ids)
        Spree::Deprecation.warn('with_ids is deprecated and will be removed in Spree 6.0. Use where(id: ids) instead.')
        where(id: ids)
      end

      scope :not_deleted, -> {
        where("#{Product.quoted_table_name}.deleted_at IS NULL or #{Product.quoted_table_name}.deleted_at >= ?", Time.zone.now)
      }

      def self.not_discontinued(only_not_discontinued = true)
        if only_not_discontinued != '0' && only_not_discontinued
          where(discontinue_on: [nil, Time.current.beginning_of_minute..])
        else
          all
        end
      end

      def self.with_currency(currency)
        joins(variants_including_master: :prices).
          where(Price.table_name => { currency: currency.upcase }).
          where.not(Price.table_name => { amount: nil }).
          distinct
      end

      def self.available(available_on = nil, currency = nil)
        scope = not_discontinued.where(status: 'active')
        if available_on
          available_on = available_on.beginning_of_minute if available_on.respond_to?(:beginning_of_minute)
          scope = scope.where("#{Product.quoted_table_name}.available_on <= ?", available_on)
        end

        unless Spree::Config.show_products_without_price
          currency ||= Spree::Store.default.default_currency
          scope = scope.with_currency(currency)
        end

        scope
      end

      def self.active(currency = nil)
        available(nil, currency)
      end

      # Deprecated — remove in 6.0. Use active(currency).in_taxon(taxon) directly.
      def self.for_filters(currency, taxon: nil)
        Spree::Deprecation.warn('for_filters is deprecated and will be removed in Spree 6.0. Use active(currency).in_taxon(taxon) instead.')
        scope = active(currency)
        scope = scope.in_taxon(taxon) if taxon.present?
        scope
      end

      # Deprecated — remove in 6.0. Not used internally.
      def self.for_user(user = nil)
        Spree::Deprecation.warn('for_user is deprecated and will be removed in Spree 6.0.')
        if user.try(:has_spree_role?, 'admin')
          with_deleted
        else
          not_deleted.where(status: 'active')
        end
      end

      # Deprecated — remove in 6.0. Not used internally.
      def self.taxons_name_eq(name)
        Spree::Deprecation.warn('taxons_name_eq is deprecated and will be removed in Spree 6.0.')
        group('spree_products.id').joins(:taxons).where(Taxon.arel_table[:name].eq(name))
      end

      # Orders products by best selling based on units_sold_count and revenue
      # from spree_products_stores (already joined via store.products).
      #
      # Uses Arel::Nodes::As so that ORDER BY expressions appear in SELECT
      # and work with DISTINCT (same pattern as the price sorting scopes).
      scope :by_best_selling, ->(order_direction = :desc) {
        sp_table = StoreProduct.table_name
        units_expr = Arel.sql("COALESCE(#{sp_table}.units_sold_count, 0)")
        revenue_expr = Arel.sql("COALESCE(#{sp_table}.revenue, 0)")

        order_dir = order_direction == :desc ? :desc : :asc

        select("#{Product.table_name}.*").
          select(Arel::Nodes::As.new(units_expr, Arel.sql('best_selling_units'))).
          select(Arel::Nodes::As.new(revenue_expr, Arel.sql('best_selling_revenue'))).
          order(units_expr.send(order_dir)).
          order(revenue_expr.send(order_dir))
      }

      # Deprecated — remove in 6.0. Use by_best_selling instead.
      def self.descend_by_popularity
        Spree::Deprecation.warn('descend_by_popularity is deprecated and will be removed in Spree 6.0. Use by_best_selling instead.')
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

      # .search_by_name — simple ILIKE on product name
      def self.search_by_name(query)
        i18n { name.lower.matches("%#{query.downcase}%") }
      end

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
