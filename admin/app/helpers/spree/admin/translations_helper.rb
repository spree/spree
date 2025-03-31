module Spree
  module Admin
    module TranslationsHelper
      def link_to_edit_translations(resource, classes: 'text-left dropdown-item')
        link_to_with_icon(
          'language',
          Spree.t(:translations),
          spree.edit_admin_translation_path(resource, resource_type: resource.class.to_s),
          class: classes
        ) if can?(:update, resource)
      end
    end
  end
end
