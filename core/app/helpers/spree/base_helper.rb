module Spree
  module BaseHelper

    # Defined because Rails' current_page? helper is not working when Spree is mounted at root.
    def current_spree_page?(url)
      path = request.fullpath.gsub(/^\/\//, '/')
      if url.is_a?(String)
        return path == url
      elsif url.is_a?(Hash)
        return path == spree.url_for(url)
      end
      return false
    end

    # human readable list of variant options
    def variant_options(v, options={})
      v.options_text
    end

    def meta_data
      object = instance_variable_get('@'+controller_name.singularize)
      meta = {}

      if object.kind_of? ActiveRecord::Base
        meta[:keywords] = object.meta_keywords if object[:meta_keywords].present?
        meta[:description] = object.meta_description if object[:meta_description].present?
      end

      if meta[:description].blank? && object.kind_of?(Spree::Product)
        meta[:description] = strip_tags(truncate(object.description, length: 160, separator: ' '))
      end

      meta.reverse_merge!({
        keywords: current_store.meta_keywords,
        description: current_store.meta_description,
      }) if meta[:keywords].blank? or meta[:description].blank?
      meta
    end

    def meta_data_tags
      meta_data.map do |name, content|
        tag('meta', name: name, content: content)
      end.join("\n")
    end

    def body_class
      @body_class ||= content_for?(:sidebar) ? 'two-col' : 'one-col'
      @body_class
    end

    def logo(image_path=Spree::Config[:logo])
      link_to image_tag(image_path), spree.root_path
    end

    def available_countries
      checkout_zone = Zone.find_by(name: Spree::Config[:checkout_zone])

      if checkout_zone && checkout_zone.kind == 'country'
        countries = checkout_zone.country_list
      else
        countries = Country.all
      end

      countries.collect do |country|
        country.name = Spree.t(country.iso, scope: 'country_names', default: country.name)
        country
      end.sort_by { |c| c.name.parameterize }
    end

    def seo_url(taxon)
      return spree.nested_taxons_path(taxon.permalink)
    end

    def gem_available?(name)
       Gem::Specification.find_by_name(name)
    rescue Gem::LoadError
       false
    rescue
       Gem.available?(name)
    end

    def display_price(product_or_variant)
      product_or_variant.price_in(current_currency).display_price.to_html
    end

    def pretty_time(time)
      [I18n.l(time.to_date, format: :long),
        time.strftime("%l:%M %p")].join(" ")
    end

    def method_missing(method_name, *args, &block)
      if image_style = image_style_from_method_name(method_name)
        define_image_method(image_style)
        self.send(method_name, *args)
      else
        super
      end
    end

    def link_to_tracking(shipment, options = {})
      return unless shipment.tracking && shipment.shipping_method

      if shipment.tracking_url
        link_to(shipment.tracking, shipment.tracking_url, options)
      else
        content_tag(:span, shipment.tracking)
      end
    end

    private

    # Returns style of image or nil
    def image_style_from_method_name(method_name)
      if method_name.to_s.match(/_image$/) && style = method_name.to_s.sub(/_image$/, '')
        possible_styles = Spree::Image.attachment_definitions[:attachment][:styles]
        style if style.in? possible_styles.with_indifferent_access
      end
    end

    def create_product_image_tag(image, product, options, style)
      options.reverse_merge! alt: image.alt.blank? ? product.name : image.alt
      image_tag image.attachment.url(style), options
    end

    def define_image_method(style)
      self.class.send :define_method, "#{style}_image" do |product, *options|
        options = options.first || {}
        if product.images.empty?
          if !product.is_a?(Spree::Variant) && !product.variant_images.empty?
            create_product_image_tag(product.variant_images.first, product, options, style)
          else
            if product.is_a?(Variant) && !product.product.variant_images.empty?
              create_product_image_tag(product.product.variant_images.first, product, options, style)
            else
              image_tag "noimage/#{style}.png", options
            end
          end
        else
          create_product_image_tag(product.images.first, product, options, style)
        end
      end
    end
  end
end
