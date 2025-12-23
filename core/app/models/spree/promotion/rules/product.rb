# A rule to limit a promotion based on products in the order.
# Can require all or any of the products to be present.
# Valid products either come from assigned product group or are assigned directly to the rule.
module Spree
  class Promotion
    module Rules
      class Product < PromotionRule
        #
        # Associations
        #
        has_many :product_promotion_rules, class_name: 'Spree::ProductPromotionRule',
                                           foreign_key: :promotion_rule_id,
                                           dependent: :destroy
        has_many :products, through: :product_promotion_rules, class_name: 'Spree::Product'

        #
        # Preferences
        #
        MATCH_POLICIES = %w(any all none)
        preference :match_policy, :string, default: MATCH_POLICIES.first

        #
        # Attributes
        #
        attr_accessor :product_ids_to_add

        #
        # Callbacks
        #
        after_save :add_products

        # scope/association that is used to test eligibility
        def eligible_products
          products
        end

        def eligible_product_ids
          @eligible_product_ids ||= product_promotion_rules.pluck(:product_id)
        end

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(order, _options = {})
          return true if eligible_product_ids.empty?

          if preferred_match_policy == 'all'
            unless eligible_product_ids.all? { |p| order.product_ids.include?(p) }
              eligibility_errors.add(:base, eligibility_error_message(:missing_product))
            end
          elsif preferred_match_policy == 'any'
            unless order.product_ids.any? { |p| eligible_product_ids.include?(p) }
              eligibility_errors.add(:base, eligibility_error_message(:no_applicable_products))
            end
          else
            unless order.product_ids.none? { |p| eligible_product_ids.include?(p) }
              eligibility_errors.add(:base, eligibility_error_message(:has_excluded_product))
            end
          end

          eligibility_errors.empty?
        end

        def actionable?(line_item)
          case preferred_match_policy
          when 'any', 'all'
            eligible_product_ids.include? line_item.variant.product_id
          when 'none'
            eligible_product_ids.exclude? line_item.variant.product_id
          else
            raise "unexpected match policy: #{preferred_match_policy.inspect}"
          end
        end

        def product_ids_string
          ActiveSupport::Deprecation.warn(
            'Please use `product_ids=` instead.'
          )
          product_ids.join(',')
        end

        def product_ids_string=(s)
          ActiveSupport::Deprecation.warn(
            'Please use `product_ids=` instead.'
          )
          self.product_ids = s
        end

        private

        def add_products
          return if product_ids_to_add.nil?

          product_promotion_rules.delete_all

          if product_ids_to_add.any?
            Spree::ProductPromotionRule.insert_all(
              product_ids_to_add.map { |product_id| { product_id: product_id, promotion_rule_id: id } }
            )
          end

          # Clear memoized values
          @eligible_product_ids = nil
        end
      end
    end
  end
end
