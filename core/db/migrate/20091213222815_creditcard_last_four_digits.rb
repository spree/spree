# Hack to allow for legacy migrations
class Creditcard < ActiveRecord::Base; end;

class CreditcardLastFourDigits < ActiveRecord::Migration
  def up
    rename_column :creditcards, :display_number, :last_digits

    Creditcard.reset_column_information
    Creditcard.all.each do |card|
      card.update_attribute(:last_digits, card.last_digits.gsub("XXXX-XXXX-XXXX-", "")) if card.last_digits.present?
    end
  end

  def down
    rename_column :creditcards, :last_digits, :display_number
  end
end
