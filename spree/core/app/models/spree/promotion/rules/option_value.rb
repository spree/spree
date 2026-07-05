module Spree
  class Promotion
    module Rules
      class OptionValue < PromotionRule
        MATCH_POLICIES = %w(any)
        preference :match_policy, :string, default: MATCH_POLICIES.first
        preference :eligible_values, :array, default: [], parse_on_set: lambda { |values|
          values.flat_map { |v| v.to_s.split(',').compact_blank.map(&:strip) }
        }

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def eligible?(promotable, _options = {})
          return false if eligible_option_value_variant_ids.empty?

          case preferred_match_policy
          when 'any'
            Spree::OptionValueVariant.where(id: eligible_option_value_variant_ids, variant_id: promotable.variant_ids).exists?
          end
        end

        def actionable?(line_item)
          return false if eligible_option_value_variant_ids.empty?

          Spree::OptionValueVariant.where(id: eligible_option_value_variant_ids, variant_id: line_item.variant_id).exists?
        end

        private

        def eligible_option_value_variant_ids
          @eligible_option_value_variant_ids ||= preferred_eligible_values.map(&:to_s)
        end
      end
    end
  end
end
