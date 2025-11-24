module Spree
  module Admin
    module NavigationHelper
      # Creates a navigation item with optional icon
      # @param [String, SafeBuffer] label The text or HTML to use as the link content
      # @param [String] url The URL for the link
      # @param [String, nil] icon Optional icon name to prepend to the label
      # @param [Boolean, nil] active Whether the link should be marked as active
      # @return [SafeBuffer] The navigation item HTML
      def nav_item(label = nil, url, icon: nil, active: nil, data: {}, **options)
        content_tag :li, class: 'nav-item', role: 'presentation' do
          if block_given?
            active_link_to url, class: 'nav-link', active: active, data: data, **options do
              yield
            end
          else
            label = icon(icon) + label if icon.present? && label.present?
            active_link_to label, url, class: 'nav-link', active: active, data: data, **options
          end
        end
      end

      # the per_page_dropdown is used on index pages like orders, products, promotions etc.
      # this method generates the select_tag
      # @return [String]
      def per_page_dropdown
        per_page_default = if @products
                             Spree::Admin::RuntimeConfig.admin_products_per_page
                           elsif @orders
                             Spree::Admin::RuntimeConfig.admin_orders_per_page
                           else
                             Spree::Admin::RuntimeConfig.admin_records_per_page
                           end

        per_page_options = [
          per_page_default,
          per_page_default * 2,
          per_page_default * 4,
          per_page_default * 8
        ]

        selected_option = (params[:per_page].try(:to_i) || per_page_default).to_i
        selected_option_label = selected_option.to_s + icon('chevron-down', class: 'ml-1 mr-0 arrow')

        dropdown(id: 'per-page-dropdown') do
          dropdown_toggle(class: 'btn-light btn-sm') do
            raw(selected_option_label)
          end +
          dropdown_menu(direction: 'top-left') do
            per_page_options.map do |option|
              link_to option, per_page_dropdown_params(option), class: "dropdown-item #{'active' if option.to_i == selected_option}"
            end.join.html_safe
          end
        end
      end

      # helper method to create proper url to apply per page ing
      # fixes https://github.com/spree/spree/issues/6888
      # @param per_page [Integer] the number of items per page
      # @return [Hash] the params to apply per page
      def per_page_dropdown_params(per_page)
        # Keep only safe query params that should survive pagination changes
        safe_params = request.query_parameters.slice(:q)
        safe_params.merge(per_page: per_page, page: nil)
      end

      # render a button link to edit a resource
      # if the current user doesn't have permission to update the resource, the button will not be rendered
      # @param resource [Spree::Product, Spree::User, Spree::Order] the resource to edit
      # @param options [Hash] the options for the link
      # @option options [String] :url the url to edit the resource (optional)
      # @return [String] the link to edit the resource
      def link_to_edit(resource, options = {})
        url = options[:url] || edit_object_url(resource)
        options[:data] ||= {}
        options[:data][:action] ||= 'edit'
        options[:class] ||= 'btn btn-light btn-sm'
        link_to_with_icon('pencil', Spree.t(:edit), url, options) if can?(:update, resource)
      end

      # render a button to delete a resource with a confirmation modal
      # if the current user doesn't have permission to destroy the resource, the button will not be rendered
      # @param resource [Spree::Product, Spree::User, Spree::Order] the resource to delete
      # @param options [Hash] the options for the link
      # @option options [String] :url the url to delete the resource (optional)
      # @return [String] the link to delete the resource
      def link_to_delete(resource, options = {})
        url = options[:url] || object_url(resource)
        name = options[:name] || Spree.t('actions.destroy')
        options[:class] ||= 'btn btn-danger btn-sm'
        options[:data] ||= { turbo_confirm: Spree.t(:are_you_sure), turbo_method: :delete }

        return unless can?(:destroy, resource)

        if options[:no_text]
          link_to_with_icon 'trash', name, url, options
        elsif options[:icon]
          link_to_with_icon options[:icon], name, url, options
        else
          link_to name, url, options
        end
      end

      # renders a link with an icon
      # @param icon_name [String] the name of the icon, eg: 'pencil', see: https://tabler.io/icons
      # @param text [String] the text of the link
      # @param url [String] the url of the link
      # @param options [Hash] the options for the link
      # @return [String] the link with the icon
      def link_to_with_icon(icon_name, text, url, options = {})
        no_text = options[:no_text]
        tooltip_text = options[:title] || (no_text ? text : nil)
        options.delete(:no_text)
        options.delete(:title) if tooltip_text

        if tooltip_text
          options[:data] ||= {}
          options[:data][:controller] = 'tooltip'
        end

        label = no_text ? '' : content_tag(:span, text)

        if icon_name
          icon = icon(icon_name, class: "icon icon-#{icon_name} #{text.blank? || no_text ? 'mr-0' : ''}")
          text = "#{icon} #{label}"
        end

        link_content = text.html_safe
        link_content += tooltip(tooltip_text) if tooltip_text

        link_to(link_content, url, options)
      end

      def link_to_export_modal
        return unless can?(:create, Spree::Export)

        button_tag(type: 'button', class: 'btn btn-light', data: { action: 'click->export-dialog#open' }) do
          icon('table-export', class: 'mr-0 mr-lg-2') +
          content_tag(:span, Spree.t(:export), class: 'd-none d-lg-inline')
        end
      end

      # renders an active link with an icon, using the active_link_to method from https://github.com/comfy/active_link_to gem
      # @param icon_name [String] the name of the icon, eg: 'pencil', see: https://tabler.io/icons
      # @param text [String] the text of the link
      # @param url [String] the url of the link
      # @param options [Hash] the options for the link
      # @return [String] the active link with the icon
      def active_link_to_with_icon(icon_name, text, url, options = {})
        no_text = options[:no_text]
        tooltip_text = options[:title] || (no_text ? text : nil)
        options.delete(:no_text)
        options.delete(:title) if tooltip_text

        if tooltip_text
          options[:data] ||= {}
          options[:data][:controller] = 'tooltip'
        end

        label = no_text ? '' : content_tag(:span, text)

        if icon_name
          icon = icon(icon_name, class: "icon icon-#{icon_name}")
          text = "#{icon} #{label}"
        end

        link_content = text.html_safe
        link_content += tooltip(tooltip_text) if tooltip_text

        active_link_to(link_content, url, options)
      end

      # renders a button with an icon (optional)
      # Override: Add disable_with option to prevent multiple request on consecutive clicks
      # @param text [String] the text of the button
      # @param icon_name [String] the name of the icon, eg: 'pencil', see: https://tabler.io/icons
      # @param button_type [String] the type of the button, eg: 'submit', 'button'
      # @param options [Hash] the options for the button
      # @return [String] the button with the icon
      def button(text, icon_name = nil, button_type = 'submit', options = {})
        if icon_name
          text = "#{icon(icon_name, class: "icon icon-#{icon_name}")} #{text}"
        end

        css_classes = options[:class] || 'btn-primary'

        button_tag(
          text.html_safe,
          options.merge(
            type: button_type,
            class: "btn #{css_classes}",
            'data-turbo-submits-with' => content_tag(:span, '', class: 'spinner-border spinner-border-sm', role: 'status')
          )
        )
      end

      def button_link_to(text, url, html_options = {})
        Spree::Deprecation.warn("button_link_to is deprecated. Use standard link_to instead.")

        if html_options[:method] &&
            !html_options[:method].to_s.casecmp('get').zero? &&
            !html_options[:remote]

          html_options[:class] = html_options[:class] ? "btn #{html_options[:class]}" : 'btn btn-primary'

          form_tag(url, method: html_options.delete(:method)) do
            button(text, html_options.delete(:icon), nil, html_options)
          end
        else
          html_options[:class] = html_options[:class] ? "btn #{html_options[:class]}" : 'btn btn-light'

          if html_options[:icon]
            icon = icon(html_options[:icon], class: "icon icon-#{html_options[:icon]}")
            text = "#{icon} #{text}"
          end

          link_to(text.html_safe, url, html_options.except(:icon))
        end
      end

      # renders a badge (active/inactive)
      # @param condition [Boolean] the condition to check
      # @param options [Hash] the options for the badge
      # @return [String] the badge with the icon
      def active_badge(condition, options = {})
        label = options[:label]
        label ||= condition ? Spree.t(:say_yes).to_s : Spree.t(:say_no).to_s
        label = icon('check') + label if condition

        css_class = condition ? 'badge-active' : 'badge-inactive'

        content_tag(:span, class: "badge  #{css_class}") do
          label
        end
      end

      # renders a back button to the previous page
      # @param default_url [String] the default url to go back to
      # @param object [Spree::Product, Spree::User, Spree::Order] the object list to go back to
      # @param label [String] the label of the back button (optional)
      # @return [String] the back button
      def page_header_back_button(default_url, object = nil, label = nil)
        url = default_url

        if object.present?
          session_key = "#{object.class.to_s.demodulize.pluralize.downcase}_return_to".to_sym
          url = session[session_key] if session[session_key].present?
        end

        link_to url, class: 'd-flex align-items-center text-decoration-none' do
          content_tag(:span, icon('chevron-left', class: 'mr-0'), class: 'btn hover-gray shadow-none px-2 d-flex align-items-center shadow-none') +
            content_tag(:span, label, class: 'font-size-base text-black')
        end
      end

      # renders an external link with an icon (eg. spree documentation website)
      # @param label [String] the label of the link
      # @param url [String] the url of the link
      # @param opts [Hash] the options for the link
      # @return [String] the external link with the icon
      def external_link_to(label, url, opts = {}, &block)
        opts[:target] ||= :blank
        opts[:rel] ||= :nofollow
        opts[:class] ||= "d-inline-flex align-items-center text-blue text-decoration-none"

        if block_given?
          link_to url, opts, &block
        else
          link_to url, opts do
            (label + icon('external-link', class: 'ml-1 mr-0 small opacity-50')).html_safe
          end
        end
      end

      # renders a link to preview a resource on the storefront using the spree_storefront_resource_url helper
      # @param resource [Spree::Product, Spree::Post] the resource to preview
      # @param options [Hash] the options for the link
      # @return [String] the link to preview the resource
      def external_page_preview_link(resource, options = {})
        resource_name = options[:name] || resource.class.name.demodulize

        url = if [Spree::Product, Spree::Post].include?(resource.class)
                spree_storefront_resource_url(resource, preview_id: resource.id)
              else
                spree_storefront_resource_url(resource)
              end

        link_to_with_icon(
          'eye',
          Spree.t('admin.utilities.preview', name: resource_name),
          url,
          class: 'text-left dropdown-item', id: "adminPreview#{resource_name}", target: :blank, data: { turbo: false }
        )
      end

      # renders a help bubble with an icon
      # @param text [String] the text of the help bubble
      # @param placement [String] the placement of the help bubble
      # @param css [String] the css class of the help bubble
      # @return [String] the help bubble with the icon
      def help_bubble(text = '', placement = 'top', css: nil)
        css ||= 'text-xs text-muted cursor-default opacity-75'
        content_tag :span, data: { controller: 'tooltip', tooltip_placement_value: placement } do
          icon('info-square-rounded', class: css) + tooltip(text)
        end
      end

      def render_breadcrumb_icon
        if settings_area?
          icon('settings')
        elsif @breadcrumb_icon
          icon(@breadcrumb_icon)
        end
      end

      # Renders the navigation for the given context
      # @param context [Symbol] the navigation context (:sidebar, :settings, etc.)
      # @param options [Hash] additional options for rendering
      # @return [String] the rendered navigation HTML
      def render_navigation(context = :sidebar, **options)
        return '' if Spree::Admin::RuntimeConfig.legacy_sidebar_navigation

        items = navigation_items(context)
        return '' if items.empty?

        render 'spree/admin/shared/navigation',
               items: items,
               context: context,
               **options
      end

      # Get navigation items for the given context
      # @param context [Symbol] the navigation context
      # @return [Array<Spree::Admin::Navigation::Item>] the visible navigation items
      def navigation_items(context = :sidebar)
        # Pass the view context (self) so that can? and other helpers are available
        Spree.admin.navigation.send(context)&.visible_items(self) || []
      end

      # Renders page tab navigation for the given context
      # @param context [Symbol] the navigation context (:tax_tabs, :shipping_tabs, etc.)
      # @param options [Hash] additional options for rendering
      # @return [String] the rendered tab navigation HTML wrapped in content_for(:page_tabs)
      def render_tab_navigation(context, **options)
        items = navigation_items(context)
        return '' if items.empty?

        content_for :page_tabs do
          items.map do |item|
            item_url = item.resolve_url(self)
            item_label = item.resolve_label
            is_active = item.active?(request.path, self)

            nav_item(item_label, item_url, active: is_active)
          end.join.html_safe
        end
      end
    end
  end
end
