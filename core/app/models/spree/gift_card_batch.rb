module Spree
  class GiftCardBatch < Spree.base_class
    extend DisplayMoney
    include Spree::SingleStoreResource

    LIMIT = ENV.fetch('GIFT_CARD_BATCH_LIMIT', 50_000).to_i

    validates :codes_count, :amount, :prefix, presence: true
    validates :codes_count, numericality: { greater_than: 0, less_than_or_equal_to: LIMIT }
    validates :amount, numericality: { greater_than: 0 }
    validates :minimum_order_amount, numericality: { greater_than_or_equal_to: 0 }

    belongs_to :store, class_name: 'Spree::Store'

    has_many :gift_cards, class_name: 'Spree::GiftCard', inverse_of: :batch

    after_create :generate_gift_cards

    auto_strip_attributes :prefix

    money_methods :amount, :minimum_order_amount

    self.whitelisted_ransackable_attributes = %w[prefix]

    def generate_gift_cards
      if codes_count < 500
        create_gift_cards
      else
        Spree::GiftCards::BulkGenerateJob.perform_later(id)
      end
    end

    def create_gift_cards
      @gift_cards_to_insert = []

      Spree::GiftCard.transaction do
        (codes_count - gift_cards.count).times do
          @gift_cards_to_insert << gift_card_hash
        end
        Spree::GiftCard.insert_all @gift_cards_to_insert if @gift_cards_to_insert.any?
      end
    end

    def generate_code
      loop do
        code = "#{prefix.downcase}#{SecureRandom.hex(3).downcase}"
        break code unless Spree::GiftCard.exists?(code: code) && @gift_cards_to_insert.detect { |gc| gc[:code] == code }
      end
    end

    private

    def gift_card_hash
      {
        gift_card_batch_id: id,
        amount: amount,
        amount_remaining: amount,
        code: generate_code,
        store_id: store_id,
        expires_at: expires_at,
        minimum_order_amount: minimum_order_amount
      }.tap do |hash|
        hash[:tenant_id] = tenant_id if defined?(ActsAsTenant)
      end
    end
  end
end
