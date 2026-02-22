module Spree
  module Admin
    module StoresHelper
      include Spree::ImagesHelper

      DEFAULT_ICON_SIZE = 40

      def store_admin_icon(store, opts = {})
        opts[:class] ||= 'rounded-md bg-white border store-icon'
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
        opts[:class] += ' store-icon rounded-lg  text-gray-900 flex items-center justify-center'
        content_tag(:span, name[0].upcase, class: opts[:class], style: "height: #{opts[:height]}px; width: #{opts[:width]}px;")
      end
    end
  end
end
