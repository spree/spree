module Spree
  module Admin
    module DropdownHelper
      def link_to_edit_translations(resource, classes: 'text-left dropdown-item')
        link_to_with_icon(
          'language',
          Spree.t(:translations),
          spree.edit_admin_translation_path(resource, resource_type: resource.class.to_s),
          class: classes
        )
      end

      def link_to_edit_metadata(resource, classes: 'text-left dropdown-item')
        link_to_with_icon(
          'database',
          Spree.t(:metadata),
          spree.edit_admin_metadata_path(resource, resource_type: resource.class.to_s),
          class: classes
        )
      end
    end
  end
end
