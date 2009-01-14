ActiveRecord::Schema.define(:version => 0) do
  create_table :petfoods, :force => true, :primary_key => :the_petfood_primary_key do |t|
    t.column :name, :string
    t.column :created_at, :datetime, :null => false
    t.column :updated_at, :datetime, :null => false
  end

  create_table :bow_wows, :force => true do |t|
    t.column :name, :string
    t.column :created_at, :datetime, :null => false
    t.column :updated_at, :datetime, :null => false
  end
  
  create_table :cats, :force => true do |t|
    t.column :name, :string
    t.column :cat_type, :string
    t.column :created_at, :datetime, :null => false
    t.column :updated_at, :datetime, :null => false
  end

  create_table :frogs, :force => true do |t|
    t.column :name, :string
    t.column :created_at, :datetime, :null => false
    t.column :updated_at, :datetime, :null => false
  end

  create_table :wild_boars, :force => true do |t|
    t.column :name, :string
    t.column :created_at, :datetime, :null => false
    t.column :updated_at, :datetime, :null => false
  end
  
  create_table :eaters_foodstuffs, :force => true do |t|
    t.column :foodstuff_id, :integer
    t.column :eater_id, :integer
    t.column :some_attribute, :integer, :default => 0
    t.column :eater_type, :string
    t.column :created_at, :datetime, :null => false
    t.column :updated_at, :datetime, :null => false
  end
  
  create_table :fish, :force => true do |t|
    t.column :name, :string
    t.column :speed, :integer
    t.column :created_at, :datetime, :null => false
    t.column :updated_at, :datetime, :null => false
  end
  
  create_table :whales, :force => true do |t|
    t.column :name, :string
    t.column :created_at, :datetime, :null => false
    t.column :updated_at, :datetime, :null => false
  end

  create_table :little_whale_pupils, :force => true do |t|
    t.column :whale_id, :integer
    t.column :aquatic_pupil_id, :integer
    t.column :aquatic_pupil_type, :string
    t.column :created_at, :datetime, :null => false
    t.column :updated_at, :datetime, :null => false
  end

  create_table :keep_your_enemies_close, :force => true do |t|
    t.column :enemy_id, :integer
    t.column :enemy_type, :string
    t.column :protector_id, :integer
    t.column :protector_type, :string
    t.column :created_at, :datetime, :null => false
    t.column :updated_at, :datetime, :null => false
  end  
  
  create_table :parentships, :force => true do |t|
    t.column :parent_id, :integer
    t.column :child_type, :string
    t.column :kid_id, :integer 
    t.column :created_at, :datetime, :null => false
    t.column :updated_at, :datetime, :null => false
  end                    
  
  create_table :people, :force => true do |t|
    t.column :name, :string
    t.column :age, :integer
    t.column :created_at, :datetime, :null => false
    t.column :updated_at, :datetime, :null => false
  end

end
