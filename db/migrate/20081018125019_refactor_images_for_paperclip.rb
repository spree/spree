class RefactorImagesForPaperclip < ActiveRecord::Migration
  def self.up
    # Attachment_fu columns
    remove_column :images, :thumbnail
    remove_column :images, :width
    remove_column :images, :height
    remove_column :images, :filename
    remove_column :images, :content_type
    remove_column :images, :size

    # Paperclip columns
    add_column :images, :photo_file_name,    :string
    add_column :images, :photo_content_type, :string
    add_column :images, :photo_file_size,    :integer
    add_column :images, :photo_updated_at,   :datetime
  end

  def self.down
    # Paperclip columns
    remove_column :images, :photo_file_name
    remove_column :images, :photo_content_type
    remove_column :images, :photo_file_size
    remove_column :images, :photo_updated_at
    
    # Attachment_fu columns
    add_column :images, :size, :integer
    add_column :images, :content_type, :string
    add_column :images, :filename, :string
    add_column :images, :height, :integer
    add_column :images, :width, :integer
    add_column :images, :thumbnail, :string
  end
end
