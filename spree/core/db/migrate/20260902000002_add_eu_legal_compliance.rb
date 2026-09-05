class AddEuLegalCompliance < ActiveRecord::Migration[8.1]
  def change
    change_table :spree_customers do |t|
      t.datetime :email_marketing_consent_updated_at
      t.string :email_marketing_consent_source
      t.datetime :anonymized_at, index: true
    end

    # Proof that a person accepted something at a moment in time. Kept as rows
    # rather than columns because acceptance is an event that recurs — a
    # customer accepts terms at registration and again at each checkout.
    create_table :spree_consent_records do |t|
      t.belongs_to :store, null: false, index: true
      t.references :owner, polymorphic: true, null: false, index: true
      t.string :purpose, null: false
      t.string :source, null: false
      t.boolean :accepted, null: false, default: true
      t.string :email
      t.string :ip_address
      t.string :user_agent
      # The policies as they read when accepted — slug, name and the digest of
      # the body the person actually saw.
      if t.respond_to?(:jsonb)
        t.jsonb :documents
      else
        t.json :documents
      end
      t.datetime :recorded_at, null: false
      t.timestamps
    end

    add_index :spree_consent_records, [:store_id, :purpose, :recorded_at],
              name: 'index_spree_consent_records_on_store_purpose_recorded'
    add_index :spree_consent_records, :email

    # A GDPR data subject request — access (Art. 15) or erasure (Art. 17).
    create_table :spree_data_requests do |t|
      t.belongs_to :store, null: false, index: true
      t.belongs_to :customer, null: false, index: true
      t.string :number, null: false
      t.string :download_token
      t.string :kind, null: false
      t.string :status, null: false
      t.string :email, null: false
      t.datetime :requested_at, null: false
      t.datetime :completed_at
      t.datetime :expires_at
      t.text :error_message
      # Null when the subject asked for it themselves; set when staff acted on
      # a request that arrived by email.
      t.bigint :requested_by_id
      t.timestamps
    end

    add_index :spree_data_requests, [:store_id, :number], unique: true
    add_index :spree_data_requests, :download_token, unique: true
    add_index :spree_data_requests, [:customer_id, :kind, :status],
              name: 'index_spree_data_requests_on_customer_kind_status'
    add_index :spree_data_requests, :requested_by_id
  end
end
