class UpdateLinkableResourceTypes < ActiveRecord::Migration[5.2]
  def change
    change_column_default :spree_menu_items, :linked_resource_type, 'Spree::Linkable::Uri'

    Spree::MenuItem.where(linked_resource_type: 'URL').update_all(linked_resource_type: 'Spree::Linkable::Uri')
    Spree::CmsSection.where(linked_resource_type: 'URL').update_all(linked_resource_type: 'Spree::Linkable::Uri')
    Spree::MenuItem.where(linked_resource_type: 'Home Page').update_all(linked_resource_type: 'Spree::Linkable::Homepage')
    Spree::CmsSection.where(linked_resource_type: 'Home Page').update_all(linked_resource_type: 'Spree::Linkable::Homepage')
  end
end
