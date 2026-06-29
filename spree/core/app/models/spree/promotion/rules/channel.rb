# A rule to limit a promotion based on the order's channel.
module Spree
  class Promotion
    module Rules
      class Channel < PromotionRule
        # Stored as raw IDs. Accepts prefixed IDs (`ch_…`) from API
        # callers and decodes them on write so eligibility checks compare
        # against the order's raw `channel_id` directly. Scope confines the
        # existence check to the promotion's store so cross-store channel
        # IDs can't sneak in.
        preference :channel_ids, :array, default: [],
                   parse_on_set: normalize_id_preference(
                     klass: Spree::Channel,
                     scope: ->(rule) { rule.promotion&.store&.channels || Spree::Channel.none }
                   )

        def applicable?(promotable)
          promotable.is_a?(Spree::Order)
        end

        def channels
          return Spree::Channel.none if preferred_channel_ids.blank?

          promotion.store.channels.where(id: preferred_channel_ids)
        end

        def eligible?(order, _options = {})
          return false if preferred_channel_ids.empty?
          return true if preferred_channel_ids.map(&:to_s).include?(order.channel_id.to_s)

          eligibility_errors.add(:base, eligibility_error_message(:no_matching_channel))
          false
        end
      end
    end
  end
end
