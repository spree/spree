module Spree
  module Admin
    module DialogHelper
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
