# A rule to limit a promotion based on products in the order.
# Can require all or any of the products to be present.
# Valid products either come from assigned product group or are assingned directly to the rule.
module Spree
  class Promotion
    module Rules
      class Product < PromotionRule
        has_and_belongs_to_many :products, class_name: '::Spree::Product', join_table: 'spree_products_promotion_rules', foreign_key: 'promotion_rule_id'

        MATCH_POLICIES = %w(any all none)
        preference :match_policy, :string, default: MATCH_POLICIES.first

        # scope/association that is used to test eligibility
        def eligible_products
          products
        end

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, options = {})
          return true if eligible_products.empty?

          if preferred_match_policy == 'all'
            unless eligible_products.all? {|p| order.products.include?(p) }
              eligibility_errors.add(:base, eligibility_error_message(:missing_product))
            end
          elsif preferred_match_policy == 'any'
            unless order.products.any? {|p| eligible_products.include?(p) }
              eligibility_errors.add(:base, eligibility_error_message(:no_applicable_products))
            end
          else
            unless order.products.none? {|p| eligible_products.include?(p) }
              eligibility_errors.add(:base, eligibility_error_message(:has_excluded_product))
            end
          end

          eligibility_errors.empty?
        end

        def actionable?(line_item)
          case preferred_match_policy
          when 'any', 'all'
            product_ids.include? line_item.variant.product_id
          when 'none'
            product_ids.exclude? line_item.variant.product_id
          else
            raise "unexpected match policy: #{preferred_match_policy.inspect}"
          end
        end

        def product_ids_string
          product_ids.join(',')
        end

        def product_ids_string=(s)
          self.product_ids = s.to_s.split(',').map(&:strip)
        end
      end
    end
  end
end
