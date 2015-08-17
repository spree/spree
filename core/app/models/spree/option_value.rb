module Spree
  class OptionValue < Spree::Base
    belongs_to :option_type, class_name: 'Spree::OptionType', touch: true, inverse_of: :option_values
    acts_as_list scope: :option_type
    has_and_belongs_to_many :variants, join_table: 'spree_option_values_variants', class_name: "Spree::Variant"

    validates :name, presence: true, uniqueness: { scope: :option_type_id }
    validates :presentation, presence: true

    after_touch :touch_all_variants

    self.whitelisted_ransackable_attributes = ['presentation']

    def touch_all_variants
      variants.update_all(updated_at: Time.current)
    end
  end
end
