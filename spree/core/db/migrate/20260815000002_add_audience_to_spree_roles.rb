class AddAudienceToSpreeRoles < ActiveRecord::Migration[8.1]
  # Which panel a role may be granted on. Every role that exists today is a
  # store-staff role, so the backfill is unconditional and the column is
  # required from then on — a role with no audience could be assigned on
  # either side of the tenancy boundary.
  #
  # Anonymous AR class rather than Spree::Role so the migration keeps working
  # if the model's defaults or validations change later.
  class MigrationRole < ActiveRecord::Base
    self.table_name = 'spree_roles'
  end

  def up
    add_column :spree_roles, :audience, :string

    MigrationRole.reset_column_information
    MigrationRole.where(audience: nil).update_all(audience: 'staff')

    change_column_null :spree_roles, :audience, false
    add_index :spree_roles, :audience
  end

  # Irreversible on purpose: dropping the column discards the staff/vendor
  # distinction, and re-running `up` would relabel every former vendor role
  # `staff` — widening its permission bound to the whole catalog.
  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
