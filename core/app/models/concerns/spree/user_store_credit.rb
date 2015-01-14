module Spree
  module UserStoreCredit
    extend ActiveSupport::Concern

    included do

      has_many :store_credits, -> { includes(:credit_type) }
      has_many :store_credit_events, through: :store_credits

      def total_available_store_credit
        store_credits.reload.to_a.sum{ |credit| credit.amount_remaining }
      end
      
    end
  end
end
