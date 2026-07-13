module Spree
  class Promotion
    module Rules
      # Promotion rule matching an order against a set of Spree::Category records.
      # Renamed from Spree::Promotion::Rules::Taxon in 6.0 (alias kept for one
      # release). Existing spree_promotion_rules.type strings are backfilled by the
      # Phase 4 data migration; the alias keeps old rows resolving until then.
      class Category < PromotionRule
        #
        # Associations
        #
        has_many :promotion_rule_categories, class_name: 'Spree::PromotionRuleCategory',
                                             foreign_key: 'promotion_rule_id',
                                             dependent: :destroy
        has_many :categories, through: :promotion_rule_categories, class_name: 'Spree::Category', source: :category

        def self.additional_permitted_attributes
          [category_ids: []]
        end

        # Wire-format shorthand is `category`. `key` (instance) cascades through `api_type`.
        def self.api_type
          'category'
        end

        # Decode prefixed IDs before delegating to the generated setter (direct
        # calls bypass PrefixedId's assign_attributes auto-resolver).
        def category_ids=(ids)
          super(Array(ids).map do |id|
            Spree::PrefixedId.prefixed_id?(id) ? Spree::Category.find_by_param!(id).id : id
          end)
        end

        #
        # Preferences
        #
        MATCH_POLICIES = %w(any all)
        preference :match_policy, :string, default: MATCH_POLICIES.first

        #
        # Attributes
        #
        attr_accessor :category_ids_to_add

        #
        # Callbacks
        #
        after_save :add_categories

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible_category_ids
          @eligible_category_ids ||= promotion_rule_categories.pluck(:category_id)
        end

        def eligible?(order, _options = {})
          return true if eligible_category_ids.empty?

          order_category_ids_with_ancestors = category_ids_in_order_including_ancestors(order)

          if preferred_match_policy == 'all'
            unless eligible_category_ids.all? { |id| order_category_ids_with_ancestors.include?(id) }
              eligibility_errors.add(:base, eligibility_error_message(:missing_taxon))
            end
          else
            unless eligible_category_ids.any? { |id| order_category_ids_with_ancestors.include?(id) }
              eligibility_errors.add(:base, eligibility_error_message(:no_matching_taxons))
            end
          end

          eligibility_errors.empty?
        end

        def actionable?(line_item)
          Spree::ProductCategory.where(category_id: eligible_category_ids_including_children, product_id: line_item.product_id).exists?
        end

        #
        # Deprecated aliases (removed in 6.1)
        #
        # @deprecated Use #categories.
        def taxons
          categories
        end

        # @deprecated Use #categories=.
        def taxons=(value)
          self.categories = value
        end

        # @deprecated Use #category_ids.
        def taxon_ids
          category_ids
        end

        # @deprecated Use #category_ids=.
        def taxon_ids=(ids)
          self.category_ids = ids
        end

        # @deprecated Use #eligible_category_ids.
        alias eligible_taxon_ids eligible_category_ids

        # @deprecated Use #category_ids_to_add.
        def taxon_ids_to_add
          category_ids_to_add
        end

        def taxon_ids_to_add=(ids)
          self.category_ids_to_add = ids
        end

        def taxon_ids_string
          ActiveSupport::Deprecation.warn(
            'Please use `category_ids=` instead.'
          )
          categories.pluck(:id).join(',')
        end

        def taxon_ids_string=(s)
          ActiveSupport::Deprecation.warn(
            'Please use `category_ids=` instead.'
          )
          ids = s.to_s.split(',').map(&:strip)
          self.categories = Spree::Category.for_stores(stores).find(ids)
        end

        private

        # IDs of categories in rule including all their children
        def eligible_category_ids_including_children
          @eligible_category_ids_including_children ||= begin
            return [] if eligible_category_ids.empty?

            Spree::Category.where(id: eligible_category_ids).flat_map(&:cached_self_and_descendants_ids).uniq
          end
        end

        # IDs of categories in order that match rule categories (or their children), plus all ancestors
        def category_ids_in_order_including_ancestors(order)
          # Get category IDs from order products that are within rule categories or their children
          order_category_ids = Spree::ProductCategory.where(product_id: order.product_ids, category_id: eligible_category_ids_including_children).pluck(:category_id).uniq

          return [] if order_category_ids.empty?

          # Get those categories plus all their ancestors
          Spree::Category.where(id: order_category_ids).flat_map { |category| category.self_and_ancestors.ids }.uniq
        end

        def add_categories
          return if category_ids_to_add.nil?

          promotion_rule_categories.delete_all

          if category_ids_to_add.any?
            Spree::PromotionRuleCategory.insert_all(
              category_ids_to_add.map { |category_id| { category_id: category_id, promotion_rule_id: id } }
            )
          end

          # Clear memoized values
          @eligible_category_ids = nil
          @eligible_category_ids_including_children = nil
        end
      end
    end
  end
end
