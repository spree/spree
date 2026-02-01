module Spree
  module Admin
    module SortableTreeHelper
      def sortable_tree_bar(parent_resource, child_resource)
        partial_name = parent_resource.class.name.demodulize.underscore
        render "spree/admin/shared/sortable_tree/#{partial_name}", parent_resource: parent_resource, child_resource: child_resource
      end

      def build_sortable_tree(parent_resource, child_resource)
        descendants = []

        unless child_resource.leaf?
          child_resource.children.includes(image_attachment: :blob, square_image_attachment: :blob).each do |child_item|
            descendants << build_sortable_tree(parent_resource, child_item) unless child_resource.leaf?
          end
        end

        row = sortable_tree_bar(parent_resource, child_resource)
        container = content_tag(:div, raw(descendants.join), data: { sortable_tree_parent_id_value: child_resource.id })

        content_tag(:div, row + container,
                    id: spree_dom_id(child_resource),
                    class: 'sortable-tree-item draggable',
                    data: {
                      sortable_tree_resource_name_value: :taxon,
                      sortable_tree_update_url_value: spree.reposition_admin_taxonomy_taxon_path(child_resource.taxonomy, child_resource)
                    })
      end
    end
  end
end
