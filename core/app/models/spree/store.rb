module Spree
  class Store < ActiveRecord::Base
    validates :name, :url, :mail_from_address, presence: true
  end
end
