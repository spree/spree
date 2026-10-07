class CreateSpreeEmailTemplates < ActiveRecord::Migration[8.1]
  def change
    create_table :spree_email_templates do |t|
      t.references :store, null: false, index: false
      t.string :key, null: false
      t.string :locale, null: false
      t.string :status, null: false
      t.text :subject
      t.text :body, null: false
      t.text :base_subject
      t.text :base_body, null: false
      t.datetime :published_at, null: false
      t.references :published_by, polymorphic: true, index: true
      t.datetime :reverted_at
      t.references :reverted_by, polymorphic: true, index: true

      t.timestamps
    end

    add_index :spree_email_templates, [:store_id, :key, :locale], unique: true,
                                                                  name: 'index_spree_email_templates_on_store_key_locale'
    add_index :spree_email_templates, :status

    create_table :spree_email_template_drafts do |t|
      t.references :store, null: false, index: false
      t.string :key, null: false
      t.string :locale, null: false
      t.text :subject
      t.text :body, null: false
      t.text :base_subject
      t.text :base_body, null: false
      t.integer :lock_version, null: false, default: 0
      t.references :updated_by, polymorphic: true, index: true

      t.timestamps
    end

    add_index :spree_email_template_drafts, [:store_id, :key, :locale], unique: true,
                                                                        name: 'index_spree_email_template_drafts_on_store_key_locale'

    create_table :spree_email_template_revisions do |t|
      t.references :email_template, null: false, index: false
      t.text :subject
      t.text :body, null: false
      t.references :published_by, polymorphic: true, index: true
      t.datetime :created_at, null: false
    end

    add_index :spree_email_template_revisions, [:email_template_id, :created_at],
              name: 'index_spree_email_template_revisions_on_template_and_created'
  end
end
