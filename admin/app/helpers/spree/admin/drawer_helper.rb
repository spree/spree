module Spree
  module Admin
    module DrawerHelper
      def drawer_header(title, action = 'drawer#close')
        content_tag(:div, class: 'drawer-header') do
          content_tag(:h5, title, class: 'drawer-title') + drawer_close_button(action)
        end.html_safe
      end

      def drawer_close_button(action = 'drawer#close')
        button_tag('', type: 'button', class: 'btn-close', data: { action: action, dismiss: 'drawer', aria_label: Spree.t(:close) }).html_safe
      end

      def drawer_discard_button(action = 'drawer#close')
        button_tag(type: 'button', class: 'btn btn-light', data: { action: action, dismiss: 'drawer' }) do
          Spree.t('actions.discard')
        end.html_safe
      end
    end
  end
end
