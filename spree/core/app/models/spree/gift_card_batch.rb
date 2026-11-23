module Spree
  class GiftCardBatch < Spree.base_class
    has_prefix_id :gcb

    extend DisplayMoney
    include Spree::SingleStoreResource
    include Spree::CanonicalDecimals

    canonical_decimals :amount

    publishes_lifecycle_events

    #
    # Associations
    #
    belongs_to :created_by, class_name: Spree.admin_user_class.to_s, optional: true
    has_many :gift_cards, class_name: 'Spree::GiftCard', inverse_of: :batch, dependent: :destroy

    #
    # Validations
    #
    validates :codes_count, :amount, :prefix, presence: true
    validates :codes_count, numericality: {
      greater_than: 0,
      less_than_or_equal_to: ->(_record) { Spree::Config[:gift_card_batch_limit].to_i }
    }
    validates :currency, presence: true
    validates :amount, numericality: { greater_than: 0 }

    #
    # Callbacks
    #
    before_validation :set_currency
    after_create :generate_gift_cards

    normalizes :prefix, with: ->(value) { value.to_s.squish.presence }

    money_methods :amount

    self.whitelisted_ransackable_attributes = %w[prefix]

    def generate_gift_cards
      if codes_count < Spree::Config[:gift_card_batch_web_limit].to_i
        create_gift_cards
      else
        Spree::GiftCards::BulkGenerateJob.perform_later(id)
      end
    end

    CODE_LOOKUP_BATCH_SIZE = 1_000

    def create_gift_cards
      Spree::GiftCard.transaction do
        @gift_cards_to_insert = generate_codes(codes_count - gift_cards.count).map { |code| gift_card_hash(code) }

        if @gift_cards_to_insert.any?
          Spree::GiftCard.insert_all @gift_cards_to_insert
          publish_gift_card_created_events(@gift_cards_to_insert.pluck(:code))
        end
      end
    end

    def generate_code
      generate_codes(1, taken: Array(@gift_cards_to_insert).pluck(:code)).first
    end

    # Unique codes not yet used by any gift card, checked against the database
    # a slice at a time rather than one query per code.
    #
    # @param count [Integer] how many codes to generate
    # @param taken [Array<String>] codes to avoid besides the stored ones
    # @return [Array<String>]
    def generate_codes(count, taken: [])
      codes = Set.new
      taken = taken.to_set

      while codes.size < count
        candidates = Array.new(count - codes.size) { "#{prefix.downcase}#{SecureRandom.hex(8).downcase}" }
        candidates = candidates.uniq.reject { |code| codes.include?(code) || taken.include?(code) }

        candidates.each_slice(CODE_LOOKUP_BATCH_SIZE) do |slice|
          stored = Spree::GiftCard.where(code: slice).pluck(:code).to_set
          codes.merge(slice.reject { |code| stored.include?(code) })
        end
      end

      codes.to_a
    end

    private

    # `insert_all` skips callbacks, so the cards' own `gift_card.created`
    # lifecycle events never fire. Publish one per card once the cards are
    # committed, honouring a write made while lifecycle events were silenced.
    def publish_gift_card_created_events(codes)
      return unless Spree::GiftCard.publish_events && Spree::Events.lifecycle_enabled?

      event_name = "#{Spree::GiftCard.event_prefix}.created"

      ActiveRecord.after_all_transactions_commit do
        codes.each_slice(CODE_LOOKUP_BATCH_SIZE) do |slice|
          Spree::GiftCard.where(store_id: store_id, code: slice).includes(:store).find_each do |gift_card|
            gift_card.publish_event(event_name)
          end
        end
      end
    end

    def gift_card_hash(code)
      {
        status: :active,
        gift_card_batch_id: id,
        amount: amount,
        currency: currency,
        code: code,
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
