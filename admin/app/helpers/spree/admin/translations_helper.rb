module Spree
  module Admin
    module TranslationsHelper
      def link_to_edit_translations(resource, options = {})
        return unless Rails.application.config.spree.translatable_resources.map(&:name).include?(resource.class.name)
        return unless can?(:update, resource)

        options[:class] ||= 'dropdown-item'
        options[:data]  ||= { action: 'drawer#open', turbo_frame: :drawer }

        link_to_with_icon(
          'language',
          Spree.t(:translations),
          spree.edit_admin_translation_path(resource, resource_type: resource.class.to_s),
          options
        )
      end
    end
  end
end
