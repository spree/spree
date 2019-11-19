module Spree
  module BaseHelper
    def available_countries
      checkout_zone = Spree::Zone.find_by(name: Spree::Config[:checkout_zone])

      countries = if checkout_zone && checkout_zone.kind == 'country'
                    checkout_zone.country_list
                  else
                    Spree::Country.all
                  end

      countries.collect do |country|
        country.name = Spree.t(country.iso, scope: 'country_names', default: country.name)
        country
      end.sort_by { |c| c.name.parameterize }
    end

    def display_price(product_or_variant)
      product_or_variant.
        price_in(current_currency).
        display_price_including_vat_for(current_price_options).
        to_html
    end

    def link_to_tracking(shipment, options = {})
      return unless shipment.tracking && shipment.shipping_method

      if shipment.tracking_url
        link_to(shipment.tracking, shipment.tracking_url, options)
      else
        content_tag(:span, shipment.tracking)
      end
    end

    def logo(image_path = Spree::Config[:logo])
      path = spree.respond_to?(:root_path) ? spree.root_path : main_app.root_path

      link_to path, 'aria-label': Spree.t('go_to_homepage') do
        image_tag image_path, alt: current_store.name
      end
    end

    def meta_data
      object = instance_variable_get('@' + controller_name.singularize)
      meta = {}

      if object.is_a? ApplicationRecord
        meta[:keywords] = object.meta_keywords if object[:meta_keywords].present?
        meta[:description] = object.meta_description if object[:meta_description].present?
      end

      if meta[:description].blank? && object.is_a?(Spree::Product)
        meta[:description] = truncate(strip_tags(object.description), length: 160, separator: ' ')
      end

      if meta[:keywords].blank? || meta[:description].blank?
        meta.reverse_merge!(keywords: current_store.meta_keywords,
                            description: current_store.meta_description)
      end
      meta
    end

    def meta_data_tags
      meta_data.map do |name, content|
        tag('meta', name: name, content: content) unless name.nil? || content.nil?
      end.join("\n")
    end

    def method_missing(method_name, *args, &block)
      if image_style = image_style_from_method_name(method_name)
        define_image_method(image_style)
        send(method_name, *args)
      else
        super
      end
    end

    def pretty_time(time)
      [I18n.l(time.to_date, format: :long), time.strftime('%l:%M %p')].join(' ')
    end

    def seo_url(taxon, options = nil)
      spree.nested_taxons_path(taxon.permalink, options)
    end

    def frontend_available?
      Spree::Core::Engine.frontend_available?
    end

    private

    def create_product_image_tag(image, product, options, style)
      options[:alt] = image.alt.blank? ? product.name : image.alt
      image_tag main_app.url_for(image.url(style)), options
    end

    def define_image_method(style)
      self.class.send :define_method, "#{style}_image" do |product, *options|
        options = options.first || {}
        options[:alt] ||= product.name
        if product.images.empty?
          if !product.is_a?(Spree::Variant) && !product.variant_images.empty?
            create_product_image_tag(product.variant_images.first, product, options, style)
          elsif product.is_a?(Spree::Variant) && !product.product.variant_images.empty?
            create_product_image_tag(product.product.variant_images.first, product, options, style)
          else
            image_tag "noimage/#{style}.png", options
          end
        else
          create_product_image_tag(product.images.first, product, options, style)
        end
      end
    end

    # Returns style of image or nil
    def image_style_from_method_name(method_name)
      if method_name.to_s.match(/_image$/) && style = method_name.to_s.sub(/_image$/, '')
        style if style.in? Spree::Image.styles.with_indifferent_access
      end
    end
  end
end
