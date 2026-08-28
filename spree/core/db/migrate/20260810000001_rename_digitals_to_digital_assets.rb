class RenameDigitalsToDigitalAssets < ActiveRecord::Migration[8.1]
  def up
    rename_table :spree_digitals, :spree_digital_assets
    rename_column :spree_digital_links, :digital_id, :digital_asset_id

    # Active Storage keys attachments by the record's class name, so the files
    # on existing rows are stored under 'Spree::Digital'. Rewrite them to the
    # new class name or every already-uploaded download would look unattached.
    rewrite_attachment_record_type('Spree::Digital', 'Spree::DigitalAsset')

    # Null means "use the store's download settings". Per-asset values let one
    # catalog mix evergreen re-downloadable files with time-limited ones.
    add_column :spree_digital_assets, :authorized_clicks, :integer
    add_column :spree_digital_assets, :authorized_days, :integer
  end

  def down
    remove_column :spree_digital_assets, :authorized_days
    remove_column :spree_digital_assets, :authorized_clicks

    rewrite_attachment_record_type('Spree::DigitalAsset', 'Spree::Digital')

    rename_column :spree_digital_links, :digital_asset_id, :digital_id
    rename_table :spree_digital_assets, :spree_digitals
  end

  private

  def rewrite_attachment_record_type(from, to)
    return unless table_exists?(:active_storage_attachments)

    execute(<<~SQL.squish)
      UPDATE active_storage_attachments
      SET record_type = #{quote(to)}
      WHERE record_type = #{quote(from)}
    SQL
  end
end
