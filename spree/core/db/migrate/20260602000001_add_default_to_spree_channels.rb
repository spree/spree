class AddDefaultToSpreeChannels < ActiveRecord::Migration[7.2]
  def change
    add_column :spree_channels, :default, :boolean, null: false, default: false

    # Partial unique index: one default channel per store. Supported on
    # Postgres and SQLite; MySQL ignores the +where:+ option, so we fall
    # back to a model-level uniqueness validation there.
    unless ActiveRecord::Base.connection.adapter_name.match?(/mysql/i)
      add_index :spree_channels, :store_id, unique: true,
                where: '"default" = TRUE',
                name: 'index_spree_channels_default_per_store'
    end
  end
end
