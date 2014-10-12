class CreateSpreeTaxonsPrototypes < ActiveRecord::Migration
  def change
    create_table :spree_taxons_prototypes do |t|
      t.belongs_to :taxon, index: true
      t.belongs_to :prototype, index: true
    end
  end
end
