class AddEmailDeliveryFlagsToSpreeOrderGroups < ActiveRecord::Migration[8.1]
  def change
    # The same pair spree_orders carries, for the same reason: a confirmation
    # is sent once, and completion is replayable — a resumed finalize
    # re-publishes order_group.completed, so without a record of what was sent
    # a customer gets the same email twice. These say what happened, not what
    # the purchase is, so unlike the group's statuses they cannot be derived
    # from the children.
    add_column :spree_order_groups, :confirmation_delivered, :boolean, default: false
    add_column :spree_order_groups, :store_owner_notification_delivered, :boolean, default: false

    add_index :spree_order_groups, :confirmation_delivered
  end
end
