ActiveRecord::Schema.define(:version => 0) do
  create_table :attachments, :force => true do |t|
    t.column :db_file_id,      :integer
    t.column :parent_id,       :integer
    t.column :thumbnail,       :string
    t.column :filename,        :string, :limit => 255
    t.column :content_type,    :string, :limit => 255
    t.column :size,            :integer
    t.column :width,           :integer
    t.column :height,          :integer
    t.column :aspect_ratio,    :float
  end

  create_table :file_attachments, :force => true do |t|
    t.column :parent_id,       :integer
    t.column :thumbnail,       :string 
    t.column :filename,        :string, :limit => 255
    t.column :content_type,    :string, :limit => 255
    t.column :size,            :integer
    t.column :width,           :integer
    t.column :height,          :integer
    t.column :type,            :string
    t.column :aspect_ratio,    :float
  end

  create_table :gd2_attachments, :force => true do |t|
    t.column :parent_id,       :integer
    t.column :thumbnail,       :string 
    t.column :filename,        :string, :limit => 255
    t.column :content_type,    :string, :limit => 255
    t.column :size,            :integer
    t.column :width,           :integer
    t.column :height,          :integer
    t.column :type,            :string
  end

  create_table :image_science_attachments, :force => true do |t|
    t.column :parent_id,       :integer
    t.column :thumbnail,       :string 
    t.column :filename,        :string, :limit => 255
    t.column :content_type,    :string, :limit => 255
    t.column :size,            :integer
    t.column :width,           :integer
    t.column :height,          :integer
    t.column :type,            :string
  end

  create_table :core_image_attachments, :force => true do |t|
    t.column :parent_id,       :integer
    t.column :thumbnail,       :string 
    t.column :filename,        :string, :limit => 255
    t.column :content_type,    :string, :limit => 255
    t.column :size,            :integer
    t.column :width,           :integer
    t.column :height,          :integer
    t.column :type,            :string
  end
  
  create_table :mini_magick_attachments, :force => true do |t|
    t.column :parent_id,       :integer
    t.column :thumbnail,       :string 
    t.column :filename,        :string, :limit => 255
    t.column :content_type,    :string, :limit => 255
    t.column :size,            :integer
    t.column :width,           :integer
    t.column :height,          :integer
    t.column :type,            :string
  end

  create_table :mini_magick_attachments, :force => true do |t|
    t.column :parent_id,       :integer
    t.column :thumbnail,       :string 
    t.column :filename,        :string, :limit => 255
    t.column :content_type,    :string, :limit => 255
    t.column :size,            :integer
    t.column :width,           :integer
    t.column :height,          :integer
    t.column :type,            :string
  end

  create_table :orphan_attachments, :force => true do |t|
    t.column :db_file_id,      :integer
    t.column :filename,        :string, :limit => 255
    t.column :content_type,    :string, :limit => 255
    t.column :size,            :integer
  end
  
  create_table :minimal_attachments, :force => true do |t|
    t.column :size,            :integer
    t.column :content_type,    :string, :limit => 255
  end

  create_table :db_files, :force => true do |t|
    t.column :data, :binary
  end

  create_table :s3_attachments, :force => true do |t|
    t.column :parent_id,       :integer
    t.column :thumbnail,       :string 
    t.column :filename,        :string, :limit => 255
    t.column :content_type,    :string, :limit => 255
    t.column :size,            :integer
    t.column :width,           :integer
    t.column :height,          :integer
    t.column :type,            :string
    t.column :aspect_ratio,    :float
  end
end