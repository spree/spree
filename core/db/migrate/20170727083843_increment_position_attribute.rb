class IncrementPositionAttribute < ActiveRecord::Migration[5.1]
  def change
    ActiveRecord::Base.connection.execute(
      "update spree_variants
       set position = (position + 1)
       where product_id in (select product_id
       from spree_variants where position = 0);"
    )
  end
end
