class CreateSpreeSellerRequirements < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_seller_requirements do |t|
      t.references :store, null: false
      t.string :type, null: false

      # The operator's own copy, shown to sellers. Blank falls back to the
      # kind's translated name, so only the generic kinds have to fill it in.
      t.string :name
      t.text :description

      t.integer :position, null: false, default: 0
      t.boolean :active, null: false, default: true
      t.boolean :required, null: false, default: true

      t.text :preferences

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end

    add_index :spree_seller_requirements, [:store_id, :position]
    add_index :spree_seller_requirements, [:store_id, :type]

    create_table :spree_seller_requirement_submissions do |t|
      t.references :seller, null: false
      t.references :seller_requirement, null: false
      t.string :status, null: false # no DB default: set by the creating workflow

      t.references :submitted_by
      t.references :reviewed_by
      t.datetime :reviewed_at

      # What the seller said, and what the operator said back.
      t.text :note
      t.text :review_note
      # An external identifier the kind understands (a provider account, say).
      t.string :reference

      if t.respond_to?(:jsonb)
        t.jsonb :metadata
      else
        t.json :metadata
      end

      t.timestamps
    end

    # The latest row for a pair is the one that counts; older rows are the
    # audit trail, so the index leads with the pair and ends with recency.
    add_index :spree_seller_requirement_submissions,
              [:seller_id, :seller_requirement_id, :created_at],
              name: 'index_seller_requirement_submissions_on_pair_and_date'
  end
end
