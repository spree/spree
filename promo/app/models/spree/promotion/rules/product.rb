# A rule to limit a promotion based on products in the order.
# Can require all or any of the products to be present.
# Valid products either come from assigned product group or are assingned directly to the rule.
module Spree
  class Promotion
    module Rules
      class Product < PromotionRule
        has_and_belongs_to_many :products, :class_name => ::Spree::Product, :join_table => :spree_products_promotion_rules, :foreign_key => :promotion_rule_id
        validate :only_one_promotion_per_product

        MATCH_POLICIES = %w(any all)
        preference :match_policy, :string, :default => MATCH_POLICIES.first

        # scope/association that is used to test eligibility
        def eligible_products
          products
        end

        def eligible?(order, options = {})
          return true if eligible_products.empty?
          if preferred_match_policy == 'all'
            eligible_products.all? {|p| order.products.include?(p) }
          else
            order.products.any? {|p| eligible_products.include?(p) }
          end
        end

        def product_ids_string
          product_ids.join(',')
        end

        def product_ids_string=(s)
          self.product_ids = s.to_s.split(',').map(&:strip)
        end

        private

          def only_one_promotion_per_product
            if Spree::Promotion::Rules::Product.all.map(&:products).flatten.uniq!
              errors[:base] << "You can't create two promotions for the same product"
            end
          end
      end
    end
  end
end
