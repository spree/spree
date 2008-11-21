class AdditionalPaperclipRefactor < ActiveRecord::Migration
  def self.up
    change_table :assets do |t|
      # remove another defunct attachment_fu column
      t.remove :parent_id
      # drop extraneous records for the thumbnails (paperclip knows about these automatically - nice!)
      execute "DELETE FROM assets WHERE viewable_id IS NULL"
      # provide a default value for the type field 
      execute "UPDATE assets SET type = 'Image' WHERE type IS NULL"
    end
  end

  def self.down
    # no going back!
  end
end
