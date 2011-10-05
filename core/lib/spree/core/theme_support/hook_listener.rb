require 'deface'

module Spree
  module ThemeSupport

    # This class is all deprecated and will be removed, currently being used as bridge
    # between old style hooks and new Deface methods.
    class HookListener
      include Singleton

      def self.replace(hook_name, options = {}, &block)
        create_deface_override(:replace, hook_name, options, &block)
      end

      def self.insert_before(hook_name, options = {}, &block)
        create_deface_override(:insert_before, hook_name, options, &block)
      end

      def self.insert_after(hook_name, options = {}, &block)
        create_deface_override(:insert_after, hook_name, options, &block)
      end

      def self.insert_top(hook_name, options = {}, &block)
        create_deface_override(:insert_top, hook_name, options, &block)
      end

      def self.insert_bottom(hook_name, options = {}, &block)
        create_deface_override(:insert_bottom, hook_name, options, &block)
      end

      def self.remove(hook_name)
        add_hook_modifier(hook_name, :replace)
      end

      private
        def self.create_deface_override(target, hook_name, options, &block)
          virtual_path = migratable_hooks.detect{|path, hooks| hooks.include? hook_name.to_sym }.try(:first)
          return if virtual_path.nil?

          if block_given?
            action = "text"
            content = yield
            content.gsub!(/["]/, '\\\"')
          else
            if options.is_a? String
              action = "partial"
              content = options
            else
              if options.key? :partial
                action = "partial"
                content = options[:partial]
              elsif options.key? :text
                action = "text"
                content = options[:text]
              elsif options.key? :template
                action = "template"
                content = options[:template]
              end
            end
          end
          content ||= ""

          override = %Q{Deface::Override.new(:virtual_path => "#{virtual_path}",
                     :name => "converted_#{hook_name}_#{rand(1000000000)}",
                     :#{target} => "[data-hook='#{hook_name}'], ##{hook_name}[data-hook]",
                     :#{action} => "#{content}",
                     :disabled => false)}

          warn "[DEPRECATION] `#{target}` hook method is deprecated, replace hook call with: \n#{override}\n"
          eval override
        end

        def self.migratable_hooks
          {
            'shared/_user_form' => [:signup_below_password_fields],
            'user_registrations/new' => [:signup, :signup_inside_form, :login_extras],
            'user_sessions/new' => [:login, :login_extras],
            'users/show' => [:account_summary, :account_my_orders],
            'admin/overview/index' => [:admin_dashboard, :admin_dashboard_left, :admin_dashboard_center, :admin_dashboard_right, :admin_dashboard_welcome ],
            'admin/configurations/index' => [:admin_configurations_menu],
            'admin/mail_methods/index' => [:admin_mail_methods_index_headers, :admin_mail_methods_index_header_actions,
                                           :admin_mail_methods_index_rows, :admin_mail_methods_index_row_actions],
            'admin/orders/_form' => [:admin_order_form_line_items_headers, :admin_order_form_line_items_header_actions,
                                    :admin_order_form_subtotal, :admin_order_form_adjustments, :admin_order_form_total, :admin_order_form_buttons],
            'admin/orders/_line_item' => [:admin_order_form_line_item_row, :admin_order_form_line_item_actions],
            'admin/orders/edit' => [:admin_order_edit_buttons, :admin_order_edit_header, :admin_order_edit_form],
            'admin/orders/index' => [:admin_orders_index_headers, :admin_orders_index_header_actions, :admin_orders_index_rows, :admin_orders_index_row_actions,
                                     :admin_orders_index_search, :admin_orders_index_search_buttons],
            'admin/orders/new' => [:admin_order_new_header, :admin_order_new_form],
            'admin/orders/show' => [:admin_order_show_buttons, :admin_order_show_addresses, :admin_order_show_details],
            'admin/payment_methods/index' => [:admin_payment_methods_index_headers, :admin_payment_methods_index_header_actions,
                                              :admin_payment_methods_index_rows, :admin_payment_methods_index_row_actions],
            'admin/product_scopes/_form' => [:admin_product_form_left, :admin_product_form_right, :admin_product_form_meta, :admin_product_form_additional_fields],
            'admin/products/_form' => [:admin_product_form_left, :admin_product_form_right, :admin_product_form_meta, :admin_product_form_additional_fields],
            'admin/products/index' => [:admin_products_index_headers, :admin_products_index_header_actions, :admin_products_index_rows, :admin_products_index_search,
                                       :admin_products_index_row_actions, :admin_products_sidebar, :admin_products_index_search_buttons],
            'spree/admin/shared/_configuration_menu' => [:admin_configurations_sidebar_menu],
            'spree/admin/shared/_order_tabs' => [:admin_order_tabs],
            'spree/admin/shared/_product_sub_menu' => [:admin_product_sub_tabs],
            'spree/admin/shared/_product_tabs' => [:admin_product_tabs],
            'admin/shipments/_form' => [:admin_shipment_form_inventory_units, :admin_shipment_form_address, :admin_shipment_form_details],
            'admin/shipments/edit' => [:admin_shipment_edit_buttons, :admin_shipment_edit_header, :admin_shipment_edit_form, :admin_shipment_edit_form_buttons],
            'admin/shipments/index' => [:admin_shipments_index_headers, :admin_shipments_index_header_actions, :admin_shipments_index_rows,
                                        :admin_shipments_index_row_actions],
            'admin/shipments/new' => [:admin_shipment_new_header, :admin_shipment_new_form, :admin_shipment_new_form_buttons],
            'admin/shipping_methods/_form' => [:admin_shipping_method_form_fields, :admin_shipping_method_form_calculator_fields],
            'admin/shipping_methods/edit' => [:admin_shipping_method_edit_form_header, :admin_shipping_method_edit_form, :admin_shipping_method_edit_form_buttons],
            'admin/shipping_methods/index' => [:admin_shipping_methods_index_headers, :admin_shipping_methods_index_header_actions,
                                               :admin_shipping_methods_index_rows, :admin_shipping_methods_index_row_actions],
            'admin/shipping_methods/new' => [:admin_shipping_method_new_form_header, :admin_shipping_method_new_form, :admin_shipping_method_new_form_buttons],
            'admin/taxonomies/_form' => [:admin_inside_taxonomy_form],
            'admin/taxons/_form' => [:admin_inside_taxon_form],
            'admin/trackers/_form' => [:additional_tracker_fields],
            'admin/trackers/index' => [:admin_trackers_index_headers, :admin_trackers_index_rows],
            'admin/users/_form' => [:admin_user_form_fields, :admin_user_form_roles],
            'admin/users/edit' => [:admin_user_edit_form_header, :admin_user_edit_form, :admin_user_edit_form_button],
            'admin/users/index' => [:admin_users_index_headers, :admin_users_index_header_actions, :admin_users_index_rows, :admin_users_index_row_actions,
                                    :admin_users_index_search, :admin_users_index_search_buttons],
            'admin/users/new' => [:admin_user_new_form_header, :admin_user_new_form, :admin_user_new_form_buttons],
            'admin/variants/edit' => [:admin_variant_edit_form],
            'admin/variants/new' => [:admin_variant_new_form],
            'checkout/_payment' => [:checkout_payment_step, :coupon_code_field],
            'checkout/edit' => [:checkout_summary_box],
            'layouts/admin' => [:admin_inside_head, :admin_login_navigation_bar, :admin_tabs, :admin_footer_scripts],
            'layouts/spree_application' => [:inside_head, :sidebar],
            'orders/_form' => [:cart_items_headers],
            'orders/_line_item' => [:cart_item_image, :cart_item_description, :cart_item_price, :cart_item_quantity, :cart_item_total, :cart_item_delete],
            'orders/edit' => [:empty_cart, :outside_cart_form, :inside_cart_form, :cart_items],
            'products/_cart_form' => [:inside_product_cart_form, :product_price],
            'products/_taxons' => [:product_taxons],
            'products/index' => [:homepage_sidebar_navigation, :search_results, :homepage_products],
            'products/show' => [:product_images, :product_description, :product_properties, :cart_form],
            'shared/_basic_layout' => [:sidebar],
            'shared/_products' => [:products_list_item],
            'shared/_footer' => [:footer_left, :footer_right],
            'shared/_nav_bar' => [:shared_login_bar],
            'shared/_order_details' => [:order_details_line_items_headers, :order_details_line_item_row, :order_details_subtotal, :order_details_adjustments,
                                       :order_details_total],
            'taxons/show' => [:taxon_sidebar_navigation, :taxon_products, :taxon_children]
          }
        end
    end

  end
end
