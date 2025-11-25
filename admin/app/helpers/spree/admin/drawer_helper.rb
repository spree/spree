module Spree
  module Admin
    module DrawerHelper
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
