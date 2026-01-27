# frozen_string_literal: true

module Spree
  module Admin
    module ApiKeysHelper
      def api_key_type_options
        Spree::ApiKey::KEY_TYPES.map do |type|
          [Spree.t("admin.api_keys.key_types.#{type}"), type]
        end
      end

      def api_key_status_badge(api_key)
        if api_key.active?
          content_tag(:span, icon('check') + Spree.t('admin.api_keys.statuses.active'), class: 'badge badge-success')
        else
          content_tag(:span, icon('alert-triangle') + Spree.t('admin.api_keys.statuses.revoked'), class: 'badge badge-danger')
        end
      end

      def api_key_type_badge(api_key)
        badge_class = api_key.publishable? ? 'badge-light' : 'badge-warning'
        icon = api_key.publishable? ? 'eye' : 'lock-password'
        content_tag(:span, icon(icon) + Spree.t("admin.api_keys.key_types.#{api_key.key_type}"), class: "badge #{badge_class}")
      end

      def masked_api_key(api_key)
        token = api_key.token
        "#{token[0..6]}#{'*' * 16}#{token[-4..]}"
      end
    end
  end
end
