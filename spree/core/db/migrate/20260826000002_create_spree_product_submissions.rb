class CreateSpreeProductSubmissions < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_product_submissions do |t|
      t.references :product, null: false
      t.string :status, null: false # no DB default: set by the creating workflow

      t.references :submitted_by
      t.references :reviewed_by
      t.datetime :reviewed_at

      # The operator's, and shown to the seller. `note` stays free for the
      # seller's own message, as on spree_seller_requirement_submissions.
      t.text :review_note

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end

    # The latest row for a product is the one that counts; older rows are the
    # audit trail, so the index leads with the product and ends with recency.
    add_index :spree_product_submissions, [:product_id, :created_at]
  end
end
