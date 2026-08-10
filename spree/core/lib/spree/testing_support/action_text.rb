# frozen_string_literal: true

# Spree 6.0 stores rich text in its own columns and neither loads Action Text
# nor creates its tables. The upgrade tasks still read
# +action_text_rich_texts+ to copy legacy content out of it, so specs covering
# those tasks have to stand the pre-upgrade table up themselves.
#
#   RSpec.describe '...' do
#     include_context 'with legacy Action Text'
#   end
RSpec.shared_context 'with legacy Action Text' do
  before(:all) do
    require 'action_text/engine'

    connection = ActiveRecord::Base.connection
    unless connection.table_exists?(:action_text_rich_texts)
      connection.create_table :action_text_rich_texts do |t|
        t.string :name, null: false
        t.text :body
        t.string :record_type, null: false
        t.bigint :record_id, null: false
        t.string :locale, null: false, default: 'en'
        t.timestamps
      end
    end

    ActionText::RichText.reset_column_information
  end

  after(:all) do
    ActiveRecord::Base.connection.drop_table(:action_text_rich_texts, if_exists: true)
  end
end
