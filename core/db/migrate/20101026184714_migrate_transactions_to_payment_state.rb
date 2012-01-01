class Transaction < ActiveRecord::Base; end
class CreditcardTxn < Transaction; end

class MigrateTransactionsToPaymentState < ActiveRecord::Migration

  AUTHORIZED=1
  COMPLETED=2
  PURCHASED=3
  VOIDED = 4
  CREDITED =5

  PAYMENT_COMPLETE = 'completed'
  PAYMENT_VOID = 'void'
  PAYMENT_PENDING = 'pending'
  
  # Temporarily set the table back to payments
  Spree::Payment.table_name = 'payments'

  def up
    migrate_authorized_only_transactions
    migrate_voided_transactions
    migrate_completed_transactions
    migrate_purchased_transactions
    migrate_credited_transactions

    Spree::Payment.table_name = 'spree_payments'
  end

  def migrate_credited_transactions
    credited = Transaction.find_by_sql("SELECT * FROM transactions WHERE txn_type = #{CREDITED}")
    credited.each do |tx|
      payment = Spree::Payment.find(tx)
      order = payment.order
      order.create_payment(
        :amount => tx.amount,
        :source_id => payment.source_id, :source_type => 'Creditcard',
        :payment_method_id => payment.payment_method_id, :state => PAYMENT_COMPLETE,
        :avs_response => tx.avs_response, :response_code => tx.response_code
      )
    end
    credited.each(&:destroy)
  end

  def migrate_voided_transactions
    voided = Transaction.find_by_sql("SELECT * FROM transactions WHERE txn_type = #{VOIDED}")
    voided.each do |tx|
      update_payment(tx, PAYMENT_VOID)
    end
    unless voided.empty?
      all_but_credited = [AUTHORIZED, COMPLETED, PURCHASED, VOIDED]
      voided_and_subsequent_transactions = Transaction.find_by_sql("SELECT * FROM transactions WHERE payment_id IN (#{voided.map(&:payment_id).join(',')}) AND txn_type IN (#{all_but_credited.join(',')})")
      voided_and_subsequent_transactions.each(&:destroy)
    end
  end

  def migrate_purchased_transactions
    migrate_transactions(PURCHASED)
  end

  def migrate_completed_transactions
    migrate_transactions(COMPLETED)
  end

  def migrate_transactions(type)
    txs = Transaction.find_by_sql("SELECT * FROM transactions WHERE txn_type = #{type}")
    txs.each do |tx|
      update_payment(tx, PAYMENT_COMPLETE)
    end
    txs.each(&:destroy)
  end

  def migrate_authorized_only_transactions
    if (ActiveRecord::Base.connection.adapter_name == 'PostgreSQL')
      group_by_clause = 'GROUP BY transactions.' + Transaction.column_names.join(', transactions.')
    else
      group_by_clause = 'GROUP BY payment_id'
    end
    authorized_only = Transaction.find_by_sql("SELECT * FROM transactions #{group_by_clause} HAVING COUNT(payment_id) = 1 AND txn_type = #{AUTHORIZED}")
    authorized_only.each do |tx|
      update_payment(tx, PAYMENT_PENDING)
    end
    authorized_only.each(&:destroy)
  end

  def update_payment(tx, state)
    payment = Spree::Payment.find(tx.payment_id)
    payment.update_attributes_without_callbacks({
      :state => state,
      :source_type => 'Creditcard',
      :amount => tx.amount,
      :response_code => tx.response_code,
      :avs_response => tx.avs_response
    })
  end

  def down
  end
end
