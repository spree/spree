module Spree
  class Promotion
    module Rules
      class OptionValue < Spree::PromotionRule
        MATCH_POLICIES = %w(any)
        preference :match_policy, :string, default: MATCH_POLICIES.first
        # Stored as raw Spree::OptionValue ids. Accepts prefixed IDs (`optval_…`)
        # from API callers and decodes them on write so eligibility checks compare
        # against stable option-value rows, not join-table ids that shift when
        # variants are reconfigured.
        preference :eligible_values, :array, default: [],
                   parse_on_set: normalize_id_preference(klass: Spree::OptionValue)

        # @param promotable [Object]
        # @return [Boolean]
        def applicable?(promotable)
          promotable.is_a?(Spree::Order) || promotable.is_a?(Spree::Cart)
        end

        # @return [ActiveRecord::Relation<Spree::OptionValue>]
        def option_values
          return Spree::OptionValue.none if preferred_eligible_values.blank?

          Spree::OptionValue.where(id: preferred_eligible_values)
        end

        # @param promotable [Spree::Order, Spree::Cart]
        # @param _options [Hash]
        # @return [Boolean]
        def eligible?(promotable, _options = {})
          return false if eligible_option_value_ids.empty?

          case preferred_match_policy
          when 'any'
            Spree::OptionValueVariant.where(
              option_value_id: eligible_option_value_ids,
              variant_id: promotable.variant_ids
            ).exists?
          end
        end

        # @param line_item [Spree::LineItem]
        # @return [Boolean]
        def actionable?(line_item)
          return false if eligible_option_value_ids.empty?

          Spree::OptionValueVariant.where(
            option_value_id: eligible_option_value_ids,
            variant_id: line_item.variant_id
          ).exists?
        end

        private

        def eligible_option_value_ids
          @eligible_option_value_ids ||= preferred_eligible_values.map(&:to_s)
        end
      end
    end
  end
end
