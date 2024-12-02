module Spree
  module Admin
    module ProductsHelper
      def display_admin_price(product_or_variant)
        price_in_current_currency = product_or_variant.price_in(current_currency)

        if price_in_current_currency.amount
          price_in_current_currency.display_price_including_vat_for(current_price_options).to_html
        end
      end

      def display_inventory(product_or_variant)
        if product_or_variant.total_on_hand == BigDecimal::INFINITY
          content_tag :span, class: 'text-muted' do
            Spree.t(:not_tracking_inventory)
          end
        else
          stock = if product_or_variant.total_on_hand.positive?
                    "#{product_or_variant.total_on_hand} #{Spree.t(:in_stock).downcase}"
                  else
                    content_tag(:span, "0 #{Spree.t(:in_stock).downcase}", class: 'text-danger')
                  end
          if product_or_variant.respond_to?(:variants) && product_or_variant.variants.size.positive?
            stock += " #{Spree.t(:for)} #{product_or_variant.variants.size} #{Spree.t(:variants).downcase}"
          end
          stock
        end
      end

      # we use this method to fetch images for media gallery on product form
      # for new products we use session to store temporary assets not tied to any variant/product (yet)
      def media_form_assets(variant)
        if variant&.persisted?
          variant.images
        elsif session[:uploaded_asset_ids].present?
          Spree::Image.accessible_by(current_ability, :manage).where(id: session[:uploaded_asset_ids].split(','))
        end
      end

      def product_status(product)
        if product.deleted?
          content_tag(:span, 'Deleted', class: 'badge  badge-danger')
        else
          content_tag(:span, class: "badge  badge-#{product.status}") do
            if product.active?
              icon('check')
            else
              ''
            end + available_status(product)
          end.html_safe
        end
      end

      def product_currencies(product)
        product_currencies = product.prices_including_master.map(&:currency).compact.uniq.map do |currency|
          ::Money::Currency.find(currency)
        end

        (supported_currencies_list + product_currencies).compact.uniq
      end

      # will return a human readable string
      def available_status(product)
        return Spree.t('admin.products.draft') if product.draft?
        return Spree.t('admin.products.active') if product.available?
        return Spree.t('admin.products.archived') if product.archived?
        return Spree.t('admin.products.paused') if product.paused?
        return Spree.t('admin.products.deleted') if product.deleted?
        return ''
      end

      def available_status_options(product)
        options = ['draft', 'active', 'archived']
        options.delete('active') if cannot?(:activate, product)
        options.map { |status| [Spree.t(status), status] }
      end

      def product_attribute_overriden?(attribute, product = nil)
        product ||= @product
        product.locked_data.key?(attribute.to_s)
      end

      def map_categories(product)
        category_tree = ['n/a', 'n/a']

        category = product.main_taxon&.pretty_name.to_s
        return category_tree if category.blank?

        category.split('->').map(&:strip).map.with_index { |c, index| category_tree[index] = c }

        category_tree
      end

      def product_filter_status_dropdown_value
        case params[:q][:status_eq]
        when 'active'
          Spree.t('admin.products.active')
        when 'draft'
          Spree.t('admin.products.draft')
        when 'archived'
          Spree.t('admin.products.archived')
        else
          'All statuses'
        end
      end

      def product_filter_stock_dropdown_value
        if params[:q][:in_stock_items] == '1'
          Spree.t('admin.products.in_stock')
        elsif params[:q][:out_of_stock_items] == '1'
          Spree.t('admin.products.out_of_stock')
        else
          'Any stock'
        end
      end
    end
  end
end
