class GenerateAnonymousUsers < ActiveRecord::Migration
  def self.up
    Spree::User.reset_column_information
    Spree::Order.where(:user_id => nil).each do |order|
      user = Spree::User.anonymous!
      user.email ||= order.email
      order.user = user
      order.save!
    end
  end

  def self.down
  end
end
