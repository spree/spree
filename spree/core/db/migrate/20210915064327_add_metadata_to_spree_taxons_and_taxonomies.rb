class AddMetadataToSpreeTaxonsAndTaxonomies < ActiveRecord::Migration[5.2]
  def change
    %i[
      spree_taxons
      spree_taxonomies
    ].each do |table_name|
      change_table table_name do |t|
        if t.respond_to? :jsonb
          add_column table_name, :metadata, :jsonb
        else
          add_column table_name, :metadata, :json
        end
      end
    end
  end
end
