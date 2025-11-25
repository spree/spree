module Spree
  module Admin
    module ModalHelper
      # render a header for the modal
      # @param title [String, Proc] the title of the modal
      # @return [String]
      def modal_header(title)
        Spree::Deprecation.warn('Bootstrap modals are deprecated and will be removed in Spree 6. Please use native dialogs with `dialog_header` helper.')

        title = capture(&title) if block_given?
        content_tag(:div, class: 'modal-header') do
          content_tag(:h5, title, class: 'modal-title') + modal_close_button
        end.html_safe
      end

      # render a close button for the modal
      # @return [String]
      def modal_close_button
        button_tag('', type: 'button', class: 'btn-close', data: { dismiss: 'modal', aria_label: Spree.t(:close) }).html_safe
      end

      # render a discard button for the modal
      # @return [String]
      def modal_discard_button
        button_tag(type: 'button', class: 'btn btn-light mr-auto', data: { dismiss: 'modal' }) do
          Spree.t('actions.discard')
        end.html_safe
      end
    end
  end
end
