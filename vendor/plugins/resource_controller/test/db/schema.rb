# This file is auto-generated from the current state of the database. Instead of editing this file, 
# please use the migrations feature of ActiveRecord to incrementally modify your database, and
# then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your database schema. If you need
# to create the application database on another system, you should be using db:schema:load, not running
# all the migrations from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended to check this file into your version control system.

ActiveRecord::Schema.define(:version => 11) do

  create_table "accounts", :force => true do |t|
    t.string "name"
  end

  create_table "comments", :force => true do |t|
    t.integer "post_id"
    t.string  "author"
    t.text    "body"
  end

  create_table "options", :force => true do |t|
    t.integer "product_id"
    t.string  "title"
  end

  create_table "photos", :force => true do |t|
    t.string  "title"
    t.integer "account_id"
  end

  create_table "photos_tags", :force => true do |t|
    t.integer "photo_id"
    t.integer "tag_id"
  end

  create_table "posts", :force => true do |t|
    t.string "title", :default => ""
    t.text   "body"
  end

  create_table "products", :force => true do |t|
    t.string "name"
  end

  create_table "projects", :force => true do |t|
    t.string "title"
  end

  create_table "ratings", :force => true do |t|
    t.integer "comment_id"
    t.integer "stars"
  end

  create_table "somethings", :force => true do |t|
    t.string "title"
  end

  create_table "projects", :force => true do |t|
    t.column "title", :string
  end

  create_table "ratings", :force => true do |t|
    t.column "comment_id", :integer
    t.column "stars",      :integer
  end

  create_table "somethings", :force => true do |t|
    t.column "title", :string
  end

  create_table "tags", :force => true do |t|
    t.string "name"
  end

end
