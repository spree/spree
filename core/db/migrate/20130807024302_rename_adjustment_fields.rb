class RenameAdjustmentFields < ActiveRecord::Migration
  def up
    remove_column :spree_adjustments, :originator_id
    remove_column :spree_adjustments, :originator_type

    add_column :spree_adjustments, :order_id, :integer

    # This enables the Spree::Order#all_adjustments association to work correctly
    Spree::Adjustment.reset_column_information
    Spree::Adjustment.find_each do |adjustment|
      if adjustment.adjustable.is_a?(Spree::Order)
        adjustment.order = adjustment.adjustable
        adjustment.save
      end
    end
  end
end
