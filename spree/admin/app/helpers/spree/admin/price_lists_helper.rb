# frozen_string_literal: true

module Spree
  module Admin
    module PriceListsHelper
      def price_list_status_badge(price_list)
        badge_class = if price_list.currently_active?
                        'success'
                      elsif price_list.scheduled?
                        'info'
                      else
                        'light'
                      end
        status_key = price_list.scheduled? && price_list.currently_active? ? 'scheduled_active' : price_list.status

        content_tag(:span, Spree.t("price_list_statuses.#{status_key}"), class: "badge badge-#{badge_class}")
      end
    end
  end
end
