module Spree
  module BaseHelper
    # returns the URL of an object on the storefront
    # @param resource [Spree::Product, Spree::Category, Spree::Page] the resource to get the URL for
    # @param options [Hash] the options for the URL
    # @option options [String] :locale the locale of the resource, defaults to I18n.locale
    # @option options [String] :store the store of the resource, defaults to current_store
    # @option options [String] :relative whether to use the relative URL, defaults to false
    # @option options [String] :preview_id the preview ID of the resource, usually the ID of the resource
    # @option options [String] :variant_id the variant ID of the resource, usually the ID of the variant (only used for products)
    # @return [String] the URL of the resource
    def spree_storefront_resource_url(resource, options = {})
      options.merge!(locale: locale_param) if defined?(locale_param) && locale_param.present?

      store = options[:store] || current_store

      base_url = if options[:relative]
                   ''
                 else
                   store.storefront_url
                 end

      localize = if options[:locale].present?
                   "/#{options[:locale]}"
                 else
                   ''
                 end

      if resource.instance_of?(Spree::Product)
        preview_id = ("preview_id=#{options[:preview_id]}" if options[:preview_id].present?)

        variant_id = ("variant_id=#{options[:variant_id]}" if options[:variant_id].present?)

        params = [preview_id, variant_id].compact_blank.join('&')
        params = "?#{params}" if params.present?

        "#{base_url + localize}/products/#{resource.slug}#{params}"
      elsif resource.is_a?(Spree::Category)
        "#{base_url + localize}/t/#{resource.permalink}"
      elsif defined?(Spree::Page) && (resource.is_a?(Spree::Page) || resource.is_a?(Spree::Policy))
        "#{base_url + localize}#{resource.page_builder_url}"
      elsif defined?(Spree::PageLink) && resource.is_a?(Spree::PageLink)
        resource.linkable_url
      elsif localize.blank?
        base_url
      else
        base_url + localize
      end
    end
  end
end
