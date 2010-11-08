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

  def self.up
    migrate_authorized_only_transactions
    migrate_voided_transactions
    migrate_completed_transactions
    migrate_purchased_transactions
    migrate_credited_transactions
  end

  def self.migrate_credited_transactions
    credited = Transaction.find_by_sql("select * from transactions where txn_type = #{CREDITED}")
    credited.each do |tx|
      payment = Payment.find(tx)
      order = payment.order
      order.create_payment(
        :amount=>tx.amount,
        :source_id=>payment.source_id, :source_type=>'Creditcard',
        :payment_method_id=>payment.payment_method_id, :state=>PAYMENT_COMPLETE,
        :avs_response=>tx.avs_response, :response_code=>tx.response_code
      )
    end
    credited.each{|rec| rec.destroy }
  end

  def self.migrate_voided_transactions
    voided = Transaction.find_by_sql("select * from transactions where txn_type=#{VOIDED}")
    voided.each do |tx|
      update_payment(tx, PAYMENT_VOID)
    end
    unless voided.empty?
      all_but_credited = [AUTHORIZED, COMPLETED, PURCHASED, VOIDED]
      voided_and_subsequent_transactions = Transaction.find_by_sql("select * from transactions where payment_id in (#{voided.map(&:payment_id).join(',')}) and txn_type in (#{all_but_credited.join(',')})")
      voided_and_subsequent_transactions.each{|rec| rec.destroy }
    end
  end

  def self.migrate_purchased_transactions
    migrate_transactions(PURCHASED)
  end

  def self.migrate_completed_transactions
    migrate_transactions(COMPLETED)
  end

  def self.migrate_transactions(type)
    txs = Transaction.find_by_sql("select * from transactions where txn_type = #{type}")
    txs.each do |tx|
      update_payment(tx, PAYMENT_COMPLETE)
    end
    txs.each{|rec| rec.destroy }
  end

  def self.migrate_authorized_only_transactions
    if (ActiveRecord::Base.connection.adapter_name == 'PostgreSQL')
      group_by_clause = "group by transactions." + Transaction.column_names.join(", transactions.")
    else
      group_by_clause = "group by payment_id"
    end
    authorized_only = Transaction.find_by_sql("select * from transactions #{group_by_clause} having count(payment_id) = 1 and txn_type = #{AUTHORIZED}")
    authorized_only.each do |tx|
      update_payment(tx, PAYMENT_PENDING)
    end
    authorized_only.each {|rec| rec.destroy }
  end

  def self.update_payment(tx, state)
    payment = Payment.find(tx.payment_id)
    payment.update_attributes_without_callbacks({
      :state => state,
      :source_type => 'Creditcard',
      :amount => tx.amount,
      :response_code => tx.response_code,
      :avs_response => tx.avs_response
    })
  end

  def self.down
  end
end

