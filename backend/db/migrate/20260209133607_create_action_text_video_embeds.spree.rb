# This migration comes from spree (originally 20250217171018)
class CreateActionTextVideoEmbeds < ActiveRecord::Migration[6.1]
  def change
    create_table :action_text_video_embeds, if_not_exists: true do |t|
      t.string :url, null: false
      t.string :thumbnail_url, null: false
      t.text :raw_html, null: false

      t.timestamps
    end
  end
end
