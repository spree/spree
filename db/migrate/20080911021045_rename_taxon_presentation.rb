class RenameTaxonPresentation < ActiveRecord::Migration
  def self.up
    change_table :taxons do |t|
      t.rename :presentation, :display
    end
  end

  def self.down
    change_table :taxons do |t|
      t.rename :display, :presentation
    end
  end
end
