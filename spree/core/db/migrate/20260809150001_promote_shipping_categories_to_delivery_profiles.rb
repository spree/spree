class PromoteShippingCategoriesToDeliveryProfiles < ActiveRecord::Migration[8.1]
  # ShippingCategory promoted in place (docs/plans/6.0-delivery-profiles.md):
  # the table and the product foreign key are renamed, so 5.x category
  # assignments become profile assignments without copying. The backfill here
  # is mechanical continuity wiring only — judgement calls (store assignment
  # of formerly-global categories, default flagging, collapsing the method
  # m:n) belong to spree:upgrade:migrate_delivery_profiles.
  def up
    rename_table :spree_shipping_categories, :spree_delivery_profiles
    rename_column :spree_products, :shipping_category_id, :delivery_profile_id

    # Nullable until the upgrade task assigns stores to 5.x rows; tightened
    # in 6.1.
    add_reference :spree_delivery_profiles, :store, index: true
    add_column :spree_delivery_profiles, :default, :boolean, null: false, default: false
    # STI: profile kinds declare behavior (Shipping, Digital, extension
    # kinds) and give seeds a rename-proof handle.
    add_column :spree_delivery_profiles, :type, :string
    add_column :spree_delivery_profiles, :position, :integer, default: 0
    add_index :spree_delivery_profiles, :type

    # Origin groups partition a profile's fulfillment origins: every zone
    # and method belongs to a group, so "same products, different warehouse,
    # different rates" is one profile with two groups. Simple stores keep a
    # single nameless group covering every location and never see the layer.
    create_table :spree_delivery_origin_groups do |t|
      t.references :delivery_profile, null: false, index: true
      t.string :name
      t.integer :position, default: 0
      t.timestamps
    end

    create_table :spree_delivery_origin_group_locations do |t|
      t.references :delivery_origin_group, null: false
      t.references :stock_location, null: false
      t.timestamps
    end
    add_index :spree_delivery_origin_group_locations,
              [:delivery_origin_group_id, :stock_location_id],
              unique: true, name: 'idx_delivery_origin_group_locations_uniqueness'

    add_reference :spree_delivery_zones, :delivery_profile, index: true
    add_reference :spree_delivery_zones, :delivery_origin_group, index: true
    add_reference :spree_delivery_methods, :delivery_profile, index: true
    add_reference :spree_delivery_methods, :delivery_origin_group, index: true
    add_reference :spree_delivery_methods, :delivery_zone, index: true
    add_reference :spree_product_types, :delivery_profile, index: true

    # Behavior routes through provider and profile classes; the string
    # vocabulary goes away entirely.
    remove_column :spree_delivery_methods, :fulfillment_type
    remove_column :spree_product_types, :fulfillment_types

    backfill_store_defaults

    drop_table :spree_delivery_method_zones
  end

  def down
    create_table :spree_delivery_method_zones do |t|
      t.references :delivery_method, null: false
      t.references :delivery_zone, null: false
      t.timestamps
    end
    execute <<~SQL
      INSERT INTO spree_delivery_method_zones (delivery_method_id, delivery_zone_id, created_at, updated_at)
      SELECT id, delivery_zone_id, created_at, updated_at
      FROM spree_delivery_methods WHERE delivery_zone_id IS NOT NULL
    SQL

    if connection.respond_to?(:supports_json?) && connection.supports_json?
      add_column :spree_product_types, :fulfillment_types, :json
    else
      add_column :spree_product_types, :fulfillment_types, :text
    end
    add_column :spree_delivery_methods, :fulfillment_type, :string
    remove_reference :spree_product_types, :delivery_profile
    remove_reference :spree_delivery_methods, :delivery_zone
    remove_reference :spree_delivery_methods, :delivery_origin_group
    remove_reference :spree_delivery_methods, :delivery_profile
    remove_reference :spree_delivery_zones, :delivery_origin_group
    remove_reference :spree_delivery_zones, :delivery_profile
    drop_table :spree_delivery_origin_group_locations
    drop_table :spree_delivery_origin_groups
    remove_column :spree_delivery_profiles, :position
    remove_column :spree_delivery_profiles, :type
    remove_column :spree_delivery_profiles, :default
    remove_reference :spree_delivery_profiles, :store
    rename_column :spree_products, :delivery_profile_id, :shipping_category_id
    rename_table :spree_delivery_profiles, :spree_shipping_categories
  end

  private

  # Anonymous readers — migrations never depend on application models.
  class MigrationStore < ActiveRecord::Base
    self.table_name = 'spree_stores'
  end

  class MigrationProfile < ActiveRecord::Base
    self.table_name = 'spree_delivery_profiles'
    # The table gains an STI `type` column in this very migration. Without
    # disabling inheritance, writing the kind makes Rails try to instantiate
    # the real subclass — which is not a descendant of this reader.
    self.inheritance_column = nil
  end

  class MigrationZone < ActiveRecord::Base
    self.table_name = 'spree_delivery_zones'
  end

  class MigrationProduct < ActiveRecord::Base
    self.table_name = 'spree_products'
  end

  class MigrationMethod < ActiveRecord::Base
    self.table_name = 'spree_delivery_methods'
  end

  class MigrationMethodZone < ActiveRecord::Base
    self.table_name = 'spree_delivery_method_zones'
  end

  class MigrationOriginGroup < ActiveRecord::Base
    self.table_name = 'spree_delivery_origin_groups'
  end

  # Every store needs its default profile, and this branch's existing zones
  # and methods need a home so a migrated development database keeps
  # quoting. 5.x rows (store_id nil) are deliberately untouched here.
  def backfill_store_defaults
    MigrationStore.find_each do |store|
      profile = MigrationProfile.create!(store_id: store.id, name: 'General', default: true, type: 'Spree::DeliveryProfiles::Shipping')
      # The nameless default group: no location members means every store
      # location, so a single-group profile behaves as if the layer weren't
      # there.
      origin_group = MigrationOriginGroup.create!(delivery_profile_id: profile.id, position: 1)

      MigrationZone.where(store_id: store.id).update_all(delivery_profile_id: profile.id, delivery_origin_group_id: origin_group.id)
      # The association is required going forward; this branch's products
      # never carried a category, so they all belong to the default profile.
      MigrationProduct.where(store_id: store.id, delivery_profile_id: nil).update_all(delivery_profile_id: profile.id)

      MigrationMethod.where(store_id: store.id).find_each do |method|
        zone_ids = MigrationMethodZone.where(delivery_method_id: method.id).order(:id).pluck(:delivery_zone_id)
        if zone_ids.size > 1
          say "Delivery method #{method.id} was linked to #{zone_ids.size} zones; keeping the first — recreate the method for the other zones if both were intended."
        end
        method.update_columns(delivery_profile_id: profile.id, delivery_origin_group_id: origin_group.id, delivery_zone_id: zone_ids.first)
      end
    end
  end
end
