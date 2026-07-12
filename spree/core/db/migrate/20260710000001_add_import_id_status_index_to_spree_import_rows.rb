class AddImportIdStatusIndexToSpreeImportRows < ActiveRecord::Migration[7.2]
  def change
    # Powers the Admin API's per-poll grouped status counts and the
    # failed-rows listing without a full scan on large imports.
    add_index :spree_import_rows, [:import_id, :status]
  end
end
