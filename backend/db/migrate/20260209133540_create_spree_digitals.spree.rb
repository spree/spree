# This migration comes from spree (originally 20210929093238)
class CreateSpreeDigitals < ActiveRecord::Migration[5.2]
  def change
    create_table :spree_digitals, if_not_exists: true do |t|
      t.belongs_to :variant

      t.timestamps
    end
  end
end
