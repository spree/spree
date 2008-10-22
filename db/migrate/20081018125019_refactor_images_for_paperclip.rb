class RefactorImagesForPaperclip < ActiveRecord::Migration
  def self.up
    rename_table :images, :assets
    change_table :assets do |t|
      t.string :type   
       
      # Attachment_fu columns
      t.remove :thumbnail
      t.remove :width
      t.remove :height
      
      # Paperclip columns
      t.rename :filename, :document_file_name
      t.rename :content_type, :document_content_type
      t.rename :size, :document_size
      t.datetime  :document_updated_at
    end
          
  end

  def self.down
    
    change_table :assets do |t|
      t.remove :type
      
      # Attachment_fu columns
      t.string :thumbnail
      t.integer :width
      t.integer :height
      
      # Paperclip columns
      t.rename :document_file_name, :filename
      t.rename :document_content_type, :content_type
      t.rename :document_size, :size
      t.remove  :document_updated_at
    end
    
    rename_table :assets, :images
  end
end
