module Spree
  module Admin
    module AdjustmentsHelper
      def link_to_toggle_adjustment_state(order, adjustment, options={})
        return if adjustment.finalized?
        icon = { closed: 'icon-unlock', open: 'icon-lock' }
        alt_text = adjustment.immutable? ? Spree.t(:open) : Spree.t(:close)
        link_to_with_icon(icon[adjustment.state.to_sym], alt_text, toggle_state_admin_order_adjustment_url(order, adjustment), options)
      end

      def adjustment_state(adjustment)
        state = adjustment.state.to_sym
        if adjustment.finalized?
          Spree.t(state)
        else
          icon_for(state)
        end
      end

      def icon_for(adjustment_state)
        icon = { closed: 'icon-lock', open: 'icon-unlock' }
        content_tag(:span, '', class: icon[adjustment_state])
      end
    end
  end
end
