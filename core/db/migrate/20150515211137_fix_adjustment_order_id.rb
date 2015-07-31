class FixAdjustmentOrderId < ActiveRecord::Migration
  def change
    say 'Populate order_id from adjustable_id where appropriate'
    execute(<<-SQL.squish)
      UPDATE
        spree_adjustments
      SET
        order_id = adjustable_id
      WHERE
        adjustable_type = 'Spree::Order'
      ;
    SQL

    # Submitter of change does not care about MySQL, as it is not officially supported.
    # Still spree officials decided to provide a working code path for MySQL users, hence
    # submitter made a AR code path he could validate on PostgreSQL.
    #
    # Whoever runs a big enough MySQL installation where the AR solution hurts:
    # Will have to write a better MySQL specific equivalent.
    if Spree::Order.connection.adapter_name.eql?('MySQL')
      Spree::Adjustment.where(adjustable_type: 'Spree::LineItem').find_each do |adjustment|
        adjustment.update_columns(order_id: Spree::LineItem.find(adjustment.adjustable_id).order_id)
      end
    else
      execute(<<-SQL.squish)
        UPDATE
          spree_adjustments
        SET
          order_id =
            (SELECT order_id FROM spree_line_items WHERE spree_line_items.id = spree_adjustments.adjustable_id)
        WHERE
          adjustable_type = 'Spree::LineItem'
      SQL
    end

    say 'Fix schema for spree_adjustments order_id column'
    change_table :spree_adjustments do |t|
      t.change :order_id, :integer, null: false
    end

    # Improved schema for postgresql, uncomment if you like it:
    #
    # # Negated Logical implication.
    # #
    # # When adjustable_type is 'Spree::Order' (p) the adjustable_id must be order_id (q).
    # #
    # # When adjustable_type is NOT 'Spree::Order' the adjustable id allowed to be any value (including of order_id in
    # # case foreign keys match). XOR does not work here.
    # #
    # # Postgresql does not have an operator for logical implication. So we need to build the following truth table
    # # via AND with OR:
    # #
    # #  p q | CHECK = !(p -> q)
    # #  -----------
    # #  t t | t
    # #  t f | f
    # #  f t | t
    # #  f f | t
    # #
    # # According to de-morgans law the logical implication q -> p is equivalent to !p || q
    # #
    # execute(<<-SQL.squish)
    #   ALTER TABLE ONLY spree_adjustments
    #    ADD CONSTRAINT fk_spree_adjustments FOREIGN KEY (order_id)
    #      REFERENCES spree_orders(id) ON UPDATE RESTRICT ON DELETE RESTRICT,
    #    ADD CONSTRAINT check_spree_adjustments_order_id CHECK
    #      (adjustable_type <> 'Spree::Order' OR order_id = adjustable_id);
    # SQL
  end
end
