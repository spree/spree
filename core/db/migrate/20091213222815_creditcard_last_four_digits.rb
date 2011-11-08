class CreditcardLastFourDigits < ActiveRecord::Migration
  def up
    rename_column :creditcards, :display_number, :last_digits

    creditcards = select_all "SELECT * FROM creditcards"
    creditcards.each do |card|
      execute "UPDATE creditcards SET last_digits = '#{card['last_digits'].gsub('XXXX-XXXX-XXXX-', '')}' WHERE id = #{card['id']}" if card['last_digits'].present?
    end
  end

  def down
    rename_column :creditcards, :last_digits, :display_number
  end
end
