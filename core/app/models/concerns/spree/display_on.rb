module Spree
  module DisplayOn
    extend ActiveSupport::Concern

    DISPLAY = [:both, :front_end, :back_end].freeze

    included do
      scope :available,              -> { where(display_on: [:both]) }
      scope :available_on_front_end, -> { where(display_on: [:front_end, :both]) }
      scope :available_on_back_end,  -> { where(display_on: [:back_end, :both]) }

      validates :display_on, presence: true, inclusion: { in: DISPLAY.map(&:to_s) }
    end
  end
end
