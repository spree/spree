module Spree
  class GiftCardBatch < Spree.base_class
    has_prefix_id :gcb

    extend DisplayMoney
    include Spree::SingleStoreResource

    publishes_lifecycle_events

    #
    # Associations
    #
    belongs_to :store, class_name: 'Spree::Store'
    belongs_to :created_by, class_name: Spree.admin_user_class.to_s, optional: true
    has_many :gift_cards, class_name: 'Spree::GiftCard', inverse_of: :batch, dependent: :destroy

    #
    # Validations
    #
    validates :codes_count, :amount, :prefix, presence: true
    validates :codes_count, numericality: { greater_than: 0, less_than_or_equal_to: Spree::Config[:gift_card_batch_limit].to_i }
    validates :store, :currency, presence: true
    validates :amount, numericality: { greater_than: 0 }

    #
    # Callbacks
    #
    before_validation :set_currency
    after_create :generate_gift_cards

    normalizes :prefix, with: ->(value) { value&.to_s&.squish&.presence }

    money_methods :amount

    def amount=(amount)
      self[:amount] = Spree::LocalizedNumber.parse(amount)
    end

    self.whitelisted_ransackable_attributes = %w[prefix]

    def generate_gift_cards
      if codes_count < Spree::Config[:gift_card_batch_web_limit].to_i
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
        break code unless Spree::GiftCard.exists?(code: code) || @gift_cards_to_insert.detect { |gc| gc[:code] == code }
      end
    end

    private

    def gift_card_hash
      {
        state: :active,
        gift_card_batch_id: id,
        amount: amount,
        currency: currency,
        code: generate_code,
        store_id: store_id,
        created_by_id: created_by_id,
        expires_at: expires_at
      }
    end

    def set_currency
      self.currency ||= store&.default_currency
    end
  end
end
