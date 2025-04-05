module Spree
  module Admin
    module StoresHelper
      include Spree::ImagesHelper

      def available_stores
        @available_stores ||= Spree::Store.accessible_by(current_ability)
      end

      DEFAULT_ICON_SIZE = 40

      def store_admin_icon(store, opts = {})
        opts[:class] ||= 'rounded-sm bg-white border'
        opts[:height] ||= DEFAULT_ICON_SIZE
        opts[:width] ||= DEFAULT_ICON_SIZE

        store ||= current_store

        return unless store

        Rails.cache.fetch(["#{store.cache_key_with_version}/admin_icon", opts.to_param]) do
          if store.logo&.attached? && store.logo&.variable?
            spree_image_tag(store.logo, class: opts[:class], width: opts[:width], height: opts[:height])
          elsif store.favicon_image&.attached? && store.favicon_image&.variable?
            spree_image_tag(store.favicon_image, class: opts[:class], width: opts[:width], height: opts[:height])
          else
            first_letter_icon(store.name, opts)
          end
        end
      end

      def first_letter_icon(name, opts = {})
        opts[:height] ||= DEFAULT_ICON_SIZE
        opts[:width] ||= DEFAULT_ICON_SIZE
        opts[:class] ||= ''
        opts[:class] += ' rounded text-dark d-flex align-items-center justify-content-center bg-gray-200'
        content_tag(:span, name[0].upcase, class: opts[:class], style: "height: #{opts[:height]}px; width: #{opts[:width]}px;")
      end

      def store_logo(store = nil, options = {})
        store ||= current_store
        return unless store

        opts = { width: 30, height: 30, crop: :fit, quality: :auto, fetch_format: :auto, alt: store.name, title: store.name, class: 'with-tip' }
        opts.merge!(options)

        if store.is_a?(Spree::Store) && store.logo&.attached? && store.logo&.variable?
          spree_image_tag(store.logo, class: opts[:class], width: opts[:width], height: opts[:height])
        else
          initials = store.name.split.map(&:first).join.upcase
          content_tag(:div, initials, class: "avatar rounded with-tip bg-light",
                     style: "width: #{opts[:height]}px; height: #{opts[:height]}px;",
                     title: store.name)
        end
      end
    end
  end
end
