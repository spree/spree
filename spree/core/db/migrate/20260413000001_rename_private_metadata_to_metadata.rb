class RenamePrivateMetadataToMetadata < ActiveRecord::Migration[7.2]
  def up
    tables_with_private_metadata.each do |table_name|
      if column_exists?(table_name, :private_metadata) && !column_exists?(table_name, :metadata)
        rename_column table_name, :private_metadata, :metadata
      end

      # Drop public_metadata if it exists (deprecated, no longer used)
      if column_exists?(table_name, :public_metadata)
        remove_column table_name, :public_metadata
      end
    end
  end

  def down
    tables_with_metadata.each do |table_name|
      if column_exists?(table_name, :metadata) && !column_exists?(table_name, :private_metadata)
        rename_column table_name, :metadata, :private_metadata
      end
    end
  end

  private

  def tables_with_private_metadata
    ActiveRecord::Base.connection.tables.select do |table_name|
      column_exists?(table_name, :private_metadata)
    end
  end

  def tables_with_metadata
    ActiveRecord::Base.connection.tables.select do |table_name|
      column_exists?(table_name, :metadata) && table_name.start_with?('spree_')
    end
  end
end
