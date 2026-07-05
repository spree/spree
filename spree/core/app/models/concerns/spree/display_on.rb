module Spree
  module DisplayOn
    extend ActiveSupport::Concern

    DISPLAY = [:both, :front_end, :back_end]

    included do
      scope :available,              -> { where(display_on: [:both]) }
      scope :available_on_front_end, -> { where(display_on: [:front_end, :both]) }
      scope :available_on_back_end,  -> { where(display_on: [:back_end, :both]) }

      # 5.5 → 6.0 bridge: see docs/plans/5.5-6.0-display-on-to-boolean.md.
      # The tri-state `display_on` enum collapses to a single
      # `storefront_visible` boolean in 6.0 — `back_end` becomes `false`,
      # everything else becomes `true`. The legacy `front_end`-only value
      # (visible to customers but hidden from staff) has no real use case
      # and folds into `storefront_visible: true` on migration.
      scope :storefront_visible, -> { where.not(display_on: 'back_end') }
      scope :admin_only,         -> { where(display_on: 'back_end') }

      # Expose `storefront_visible` to Ransack so admin clients can filter
      # by it (e.g. `q[storefront_visible_eq]=true`) without knowing about
      # the underlying tri-state `display_on` column.
      ransacker :storefront_visible, type: :boolean do |parent|
        # Wrap in `Grouping` so Postgres sees `(display_on != 'back_end') = TRUE`
        # instead of the ambiguous `display_on != 'back_end' = TRUE`.
        Arel::Nodes::Grouping.new(
          Arel::Nodes::NotEqual.new(parent.table[:display_on], Arel::Nodes::Quoted.new('back_end'))
        )
      end

      self.whitelisted_ransackable_attributes =
        (whitelisted_ransackable_attributes || []) | %w[storefront_visible]

      validates :display_on, presence: true, inclusion: { in: DISPLAY.map(&:to_s) }

      def available_on_front_end?
        display_on == 'front_end' || display_on == 'both'
      end

      def storefront_visible
        display_on != 'back_end'
      end

      def storefront_visible=(value)
        self.display_on = ActiveModel::Type::Boolean.new.cast(value) ? 'both' : 'back_end'
      end
    end
  end
end
