ActiveRecord::Schema.define(:version => 2) do

  create_table :comments, :force => true do |t|
    t.integer :photo_id
    t.string :author
    t.text :body
    t.timestamps
  end

  create_table :photos, :force => true do |t|
    t.string :title
    t.text   :description
    t.timestamps
  end

end
