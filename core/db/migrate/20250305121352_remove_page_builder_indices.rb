class RemovePageBuilderIndices < ActiveRecord::Migration[7.2]
  def change
    if index_name_exists?(:spree_pages, 'index_spree_pages_on_pageable_id_and_pageable_type_and_slug')
      remove_index :spree_pages, name: 'index_spree_pages_on_pageable_id_and_pageable_type_and_slug'
    end

    if index_name_exists?(:spree_themes, 'index_spree_themes_on_store_id_and_default')
      remove_index :spree_themes, name: 'index_spree_themes_on_store_id_and_default'
    end
  end
end
