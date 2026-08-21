class AddClaimedAmountToSpreePaymentSplits < ActiveRecord::Migration[8.1]
  def change
    # What a parcel has reserved of this share but not yet drawn.
    #
    # A dispatch marks its intention before asking the gateway, so that two
    # parcels of the same order cannot draw the same money. Recording that in
    # `captured_amount` conflated it with money the gateway confirmed, and
    # anything settling against the share — a cancellation, a refund — could
    # then give back an amount that was never taken. The claim lives here and
    # moves into `captured_amount` only once the charge lands.
    add_column :spree_payment_splits, :claimed_amount, :decimal, precision: 10, scale: 2,
                                                                null: false, default: 0
  end
end
