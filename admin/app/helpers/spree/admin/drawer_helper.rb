module Spree
  module Admin
    module DrawerHelper
      def drawer_header(title)
        content_tag(:div, class: 'drawer-header') do
          content_tag(:h5, title, class: 'drawer-title') + drawer_close_button
        end.html_safe
      end

      def drawer_close_button
        button_tag('', type: 'button', class: 'btn-close', data: { action: 'drawer#close', dismiss: 'drawer', aria_label: Spree.t(:close) }).html_safe
      end

      def drawer_discard_button
        button_tag(type: 'button', class: 'btn btn-light', data: { action: 'drawer#close', dismiss: 'drawer' }) do
          Spree.t('actions.discard')
        end.html_safe
      end
    end
  end
end
