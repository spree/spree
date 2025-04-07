module Spree
  module Admin
    module ModalHelper
      def modal_header(title)
        title = capture(&title) if block_given?
        content_tag(:div, class: 'modal-header') do
          content_tag(:h5, title, class: 'modal-title') + modal_close_button
        end.html_safe
      end

      def modal_close_button
        button_tag('', type: 'button', class: 'btn-close', data: { dismiss: 'modal', aria_label: Spree.t(:close) }).html_safe
      end

      def modal_discard_button
        button_tag(type: 'button', class: 'btn btn-light', data: { dismiss: 'modal' }) do
          Spree.t('actions.discard')
        end.html_safe
      end
    end
  end
end
