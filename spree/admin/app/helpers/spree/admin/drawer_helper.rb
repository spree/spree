module Spree
  module Admin
    module DrawerHelper
      # Renders a drawer container element (slide-out panel)
      # @param id [String, nil] the id of the drawer element
      # @param controller_name [String] the Stimulus controller name (default: 'drawer')
      # @param html_options [Hash] additional HTML attributes
      # @yield the content to render inside the drawer
      # @return [String] the drawer HTML
      #
      # @example Basic usage
      #   <%= drawer do %>
      #     <%= drawer_header("Edit Product") %>
      #     <div class="drawer-body">Form fields here...</div>
      #     <div class="drawer-footer">
      #       <%= drawer_discard_button %>
      #       <%= button_tag "Save", class: "btn btn-primary" %>
      #     </div>
      #   <% end %>
      #
      # @example With custom id and controller
      #   <%= drawer(id: 'filters-drawer', controller_name: 'dialog') do %>
      #     ...
      #   <% end %>
      def drawer(id: nil, controller_name: 'drawer', **html_options, &block)
        html_options[:class] = "drawer #{html_options[:class]}".strip
        html_options[:data] ||= {}
        html_options[:data]["#{controller_name}-target".to_sym] = 'dialog'
        html_options[:id] = id if id.present?

        content_tag(:dialog, html_options, &block)
      end

      def drawer_header(title, controller_name = 'drawer')
        content_tag(:div, class: 'drawer-header') do
          content_tag(:h5, title, class: 'drawer-title') + drawer_close_button(controller_name)
        end.html_safe
      end

      def drawer_close_button(controller_name = 'drawer')
        button_tag('', type: 'button', class: 'btn-close', data: { action: "#{controller_name}#close", dismiss: controller_name, aria_label: Spree.t(:close) }).html_safe
      end

      def drawer_discard_button(controller_name = 'drawer')
        button_tag(type: 'button', class: 'btn btn-light', data: { action: "#{controller_name}#close", dismiss: controller_name }) do
          Spree.t('actions.discard')
        end.html_safe
      end
    end
  end
end
