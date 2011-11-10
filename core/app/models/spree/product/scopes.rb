module Spree
  class Product < ActiveRecord::Base
    def self.simple_scopes
      [
        :ascend_by_updated_at,
        :descend_by_updated_at,
        :ascend_by_name,
        :descend_by_name,
      ]
    end

    simple_scopes.each do |name|
      parts = name.to_s.match(/(.*)_by_(.*)/)
      order_text = "#{Spree::Product.quoted_table_name}.#{parts[2]} #{parts[1] == 'ascend' ?  "ASC" : "DESC"}"
      self.scope(name.to_s, relation.order(order_text))
    end

      def self.ascend_by_master_price
        joins(:variants_with_only_master).order("#{variant_table_name}.price ASC")
      end

      def self.descend_by_master_price
        joins(:variants_with_only_master).order("#{variant_table_name}.price DESC")
      end

      # Ryan Bates - http://railscasts.com/episodes/112
      # general merging of conditions, names following the searchlogic pattern
      scope :conditions, lambda { |*args| { :conditions => args } }

      # conditions_all is a more descriptively named enhancement of the above
      scope :conditions_all, lambda { |*args| { :conditions => [args].flatten } }

      # forming the disjunction of a list of conditions (as strings)
      scope :conditions_any, lambda { |*args|
        args = [args].flatten
        raise "non-strings in conditions_any" unless args.all? {|s| s.is_a? String}
        {:conditions => args.map {|c| "(#{c})"}.join(" OR ")}
      }

      def self.price_between(low, high)
        joins(:master).where(Spree::Variant.table_name => { :price => low..high })
      end

      def self.master_price_lte(price)
        joins(:master).where("#{variant_table_name}.price <= ?", price)
      end

      def self.master_price_gte(price)
        joins(:master).where("#{variant_table_name}.price >= ?", price)
      end

      # This scope selects products in taxon AND all its descendants
      # If you need products only within one taxon use
      #
      #   Spree::Product.taxons_id_eq(x)
      def self.in_taxon(taxon)
        joins(:taxons).where(Spree::Taxon.table_name => { :id => taxon.self_and_descendants.map(&:id) })
      end

      # This scope selects products in all taxons AND all its descendants
      # If you need products only within one taxon use
      #
      #   Spree::Product.taxons_id_eq([x,y])
      #
      def self.in_taxons(*taxons)
        taxons = get_taxons(taxons)
        taxons.first ? prepare_taxon_conditions(taxons) : {}
      end

      # for quick access to products in a group, WITHOUT using the association mechanism
      ::Spree::Product.scope :in_cached_group, lambda { |product_group|
        { :joins => "JOIN spree_product_groups_products ON #{Spree::Product.quoted_table_name}.id = spree_product_groups_products.product_id",
          :conditions => ["spree_product_groups_products.product_group_id = ?", product_group]
        }
      }

      # a scope that finds all products having property specified by name, object or id
      def self.with_property(property)
        conditions = case property
        when String          then ["#{Spree::Property.quoted_table_name}.name = ?", property]
        when Spree::Property then ["#{Spree::Property.quoted_table_name}.id = ?", property.id]
        else                      ["#{Spree::Property.quoted_table_name}.id = ?", property.to_i]
        end

        joins(:properties).where(conditions)
      end

      # a scope that finds all products having an option_type specified by name, object or id
      ::Spree::Product.scope :with_option, lambda { |option|
        conditions = case option
        when String            then ["#{Spree::OptionType.quoted_table_name}.name = ?", option]
        when Spree::OptionType then ["#{Spree::OptionType.quoted_table_name}.id = ?",   option.id]
        else                        ["#{Spree::OptionType.quoted_table_name}.id = ?",   option.to_i]
        end

        {
          :joins => :option_types,
          :conditions => conditions
        }
      }

      # a simple test for product with a certain property-value pairing
      # note that it can test for properties with NULL values, but not for absent values
      ::Spree::Product.scope :with_property_value, lambda { |property, value|
        conditions = case property
        when String          then ["#{Spree::Property.quoted_table_name}.name = ?", property]
        when Spree::Property then ["#{Spree::Property.quoted_table_name}.id = ?", property.id]
        else                      ["#{Spree::Property.quoted_table_name}.id = ?", property.to_i]
        end
        conditions = ["#{Spree::ProductProperty.quoted_table_name}.value = ? AND #{conditions[0]}", value, conditions[1]]

        {
          :joins => :properties,
          :conditions => conditions
        }
      }

      # a scope that finds all products having an option value specified by name, object or id
      ::Spree::Product.scope :with_option_value, lambda {|option, value|
        option_type_id = case option
        when String
          option_type = Spree::OptionType.find_by_name(option) || option.to_i
        when Spree::OptionType
          option.id
        else
          option.to_i
        end
        conditions = [
          "#{Spree::OptionValue.quoted_table_name}.name = ? AND #{Spree::OptionValue.quoted_table_name}.option_type_id = ?",
          value, option_type_id
        ]

        {
          :joins => { :variants => :option_values },
          :conditions => conditions
        }
      }

      # finds product having option value OR product_property
      ::Spree::Product.scope :with, lambda{ |value|
        {
          :conditions => ["#{Spree::OptionValue.quoted_table_name}.name = ? OR #{Spree::ProductProperty.quoted_table_name}.value = ?", value, value],
          :joins => { :variants => :option_values, :product_properties => [] }
        }
      }

      ::Spree::Product.scope :in_name, lambda{ |words|
        ::Spree::Product.like_any([:name], prepare_words(words))
      }

      ::Spree::Product.scope :in_name_or_keywords, lambda{ |words|
        ::Spree::Product.like_any([:name, :meta_keywords], prepare_words(words))
      }

      ::Spree::Product.scope :in_name_or_description, lambda{ |words|
        ::Spree::Product.like_any([:name, :description, :meta_description, :meta_keywords], prepare_words(words))
      }

      ::Spree::Product.scope :with_ids, lambda{ |ids|
        ids = ids.split(',') if ids.is_a?(String)
        { :conditions => {:id => ids} }
      }

      # Sorts products from most popular (poularity is extracted from how many
      # times use has put product in cart, not completed orders)
      #
      # there is alternative faster and more elegant solution, it has small drawback though,
      # it doesn stack with other scopes :/
      #
      # :joins => "LEFT OUTER JOIN (SELECT line_items.variant_id as vid, COUNT(*) as cnt FROM line_items GROUP BY line_items.variant_id) AS popularity_count ON variants.id = vid",
      # :order => 'COALESCE(cnt, 0) DESC'
      ::Spree::Product.scope :descend_by_popularity,
        {
          :joins => :master,
          :order => %Q{
             COALESCE((
               SELECT
                 COUNT(#{Spree::LineItem.quoted_table_name}.id)
               FROM
                 #{Spree::LineItem.quoted_table_name}
               JOIN
                 #{Spree::Variant.quoted_table_name} AS popular_variants
               ON
                 popular_variants.id = #{Spree::LineItem.quoted_table_name}.variant_id
               WHERE
                 popular_variants.product_id = #{Spree::Product.quoted_table_name}.id
             ), 0) DESC
          }
        }

      # Produce an array of keywords for use in scopes.
      # Always return array with at least an empty string to avoid SQL errors
      def self.prepare_words(words)
        return [''] if words.blank?
        a = words.split(/[,\s]/).map(&:strip)
        a.any? ? a : ['']
      end

      def self.get_taxons(*ids_or_records_or_names)
        ids_or_records_or_names.flatten.map { |t|
          case t
          when Integer then Spree::Taxon.find_by_id(t)
          when ActiveRecord::Base then t
          when String
            Spree::Taxon.find_by_name(t) ||
            Spree::Taxon.find(:first, :conditions => [
              "#{Spree::Taxon.quoted_table_name}.permalink LIKE ? OR #{Spree::Taxon.quoted_table_name}.permalink = ?", "%/#{t}/", "#{t}/"
            ])
          end
        }.compact.uniq
      end

    class << self
      def not_deleted
        where(arel_table[:deleted_at].eq(nil))
      end

      def available(available_on = nil)
        where(arel_table[:available_on].lteq(available_on || Time.zone.now ))
      end

      #RAILS 3 TODO - this scope doesn't match the original 2.3.x version, needs attention (but it works)
      def active
        not_deleted.available
      end

      def on_hand
        where(arel_table[:count_on_hand].gteq(0))
      end

      def id_equals(input_id)
        where(arel_table[:id].eq(input_id))
      end

      def taxons_name_eq(name)
        joins(:taxons).where(Spree::Taxon.arel_table[:name].eq(name))
      end

      private

      def variant_table_name
        Spree::Variant.quoted_table_name
      end

      # specifically avoid having an order for taxon search (conflicts with main order)
      def prepare_taxon_conditions(taxons)
        ids = taxons.map{ |taxon| taxon.self_and_descendants.map(&:id) }.flatten.uniq
        joins(:taxons).where("spree_taxons.id" => ids)
      end

    end

    if (ActiveRecord::Base.connection.adapter_name == 'PostgreSQL')
      if table_exists?
        scope :group_by_products_id, { :group => column_names.map { |col_name| "#{table_name}.#{col_name}"} }
      end
    else
      scope :group_by_products_id, { :group => "#{self.quoted_table_name}.id" }
    end
    search_methods :group_by_products_id
  end
end

