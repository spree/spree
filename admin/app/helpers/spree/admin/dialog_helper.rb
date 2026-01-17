module Spree
  module Admin
    module DialogHelper
      # Renders a dialog container element
      # @param id [String, nil] the id of the dialog element
      # @param controller_name [String] the Stimulus controller name (default: 'dialog')
      # @param html_options [Hash] additional HTML attributes
      # @yield the content to render inside the dialog
      # @return [String] the dialog HTML
      #
      # @example Basic usage
      #   <%= dialog do %>
      #     <%= dialog_header("Confirm Delete") %>
      #     <div class="dialog-body">Are you sure?</div>
      #     <div class="dialog-footer">
      #       <%= dialog_discard_button %>
      #       <%= button_tag "Delete", class: "btn btn-danger" %>
      #     </div>
      #   <% end %>
      #
      # @example With custom id and controller
      #   <%= dialog(id: 'my-dialog', controller_name: 'custom-dialog') do %>
      #     ...
      #   <% end %>
      def dialog(id: nil, controller_name: 'dialog', **html_options, &block)
        html_options[:class] = "dialog #{html_options[:class]}".strip
        html_options[:data] ||= {}
        html_options[:data]["#{controller_name}-target".to_sym] = 'dialog'
        html_options[:id] = id if id.present?

        content_tag(:dialog, html_options, &block)
      end

      def dialog_header(title, controller_name = 'dialog')
        content_tag(:div, class: 'dialog-header') do
          content_tag(:h5, title, class: 'dialog-title') + dialog_close_button(controller_name)
        end.html_safe
      end

      def dialog_close_button(controller_name = 'dialog')
        button_tag('', type: 'button', class: 'btn-close', data: { action: "#{controller_name}#close", dismiss: controller_name, aria_label: Spree.t(:close) }).html_safe
      end

      def dialog_discard_button(controller_name = 'dialog')
        button_tag(type: 'button', class: 'btn btn-light', data: { action: "#{controller_name}#close", dismiss: controller_name }) do
          Spree.t('actions.discard')
        end.html_safe
      end
    end
  end
end
