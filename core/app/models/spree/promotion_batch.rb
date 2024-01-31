module Spree
  class PromotionBatch < Spree::Base
    has_many :promotions
    belongs_to :template_promotion, class_name: 'Promotion'

    validate :validate_codes_present

    serialize :codes, type: Array, coder: YAML

    state_machine initial: :pending do
      event :start do
        transition from: :pending, to: :generating
      end

      event :complete do
        transition from: :generating, to: :completed
      end

      event :error do
        transition from: :generating, to: :error
      end
    end

    def validate_codes_present
      errors.add(:codes, Spree.t('no_codes_present')) unless codes.present?
    end
  end
end
