ActiveRecord::Schema.define(:version => 0) do
  create_table :authors, :force => true do |t|
    t.column :name,      :string
  end

  create_table :edits, :force => true do |t|
    t.column :author_id,       :integer
    t.column :article_id,      :integer
    t.column :text,            :string 
  end

  create_table :articles, :force => true do |t|
    t.column :author_id,       :integer
    t.column :name,            :string
  end
end