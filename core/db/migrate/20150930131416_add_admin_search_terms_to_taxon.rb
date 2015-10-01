class AddAdminSearchTermsToTaxon < ActiveRecord::Migration
  def change
    add_column :spree_taxons, :admin_search_terms, :string

    # generate the admin search term for the first time
    Spree::Taxon.find_each do |taxon|
      taxon.send(:generate_admin_search_terms)
    end
  end
end
