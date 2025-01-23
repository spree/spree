module Spree
  module Admin
    module StoresHelper
      def available_stores
        @available_stores ||= Spree::Store.accessible_by(current_ability)
      end

      DEFAULT_ICON_SIZE = 40

      def store_admin_icon(store, opts = {})
        opts[:class] ||= 'mr-lg-3 rounded-sm bg-white border'
        opts[:height] ||= DEFAULT_ICON_SIZE
        opts[:width] ||= DEFAULT_ICON_SIZE

        store ||= current_store

        return unless store

        Rails.cache.fetch(["#{store.cache_key_with_version}/admin_icon", opts.to_param]) do
          if store.logo&.attached? && store.logo&.variable?
            image_tag(
              main_app.cdn_image_url(
                store.logo.variant(
                  spree_image_variant_options(
                    resize_to_fill: [opts[:width] * 2, opts[:height] * 2]
                  )
                )
              ),
              class: opts[:class],
              width: opts[:width],
              height: opts[:height]
            )
          elsif store.favicon_image&.attached? && store.favicon_image&.variable?
            image_tag(
              main_app.cdn_image_url(
                store.favicon_image.variant(
                  spree_image_variant_options(
                    resize_to_fill: [opts[:width] * 2, opts[:height] * 2]
                  )
                )
              ),
              class: opts[:class],
              width: opts[:width],
              height: opts[:height]
            )
          else
            first_letter_icon(store.name, opts)
          end
        end
      end

      def first_letter_icon(name, opts = {})
        opts[:height] ||= DEFAULT_ICON_SIZE
        opts[:width] ||= DEFAULT_ICON_SIZE
        opts[:class] ||= ''
        opts[:class] += ' mr-lg-3 rounded text-dark d-flex align-items-center justify-content-center bg-gray-200'
        content_tag(:span, name[0].upcase, class: opts[:class], style: "height: #{opts[:height]}px; width: #{opts[:width]}px;")
      end

      def store_logo(store = nil, options = {})
        store ||= current_store
        return unless store

        opts = { width: 30, height: 30, crop: :fit, quality: :auto, fetch_format: :auto, alt: store.name, title: store.name, class: 'with-tip' }
        opts.merge!(options)

        if store.is_a?(Spree::Store) && store.logo&.attached? && store.logo&.variable?
          image_tag(
            main_app.cdn_image_url(
              store.logo.variant(
                spree_image_variant_options(
                  resize_to_fill: [opts[:width] * 2, opts[:height] * 2]
                )
              )
            ),
            opts
          )
        else
          initials = store.name.split.map(&:first).join.upcase
          image_tag("https://eu.ui-avatars.com/api/?name=#{initials}&background=random", width: opts[:height], height: opts[:height],
                                                                                        class: 'rounded with-tip', title: store.name)
        end
      end
    end
  end
end
