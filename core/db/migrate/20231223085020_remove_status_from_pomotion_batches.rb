class RemoveStatusFromPomotionBatches < ActiveRecord::Migration[6.1]
  def change
    remove_column(:spree_promotion_batches, :status)
  end
end
