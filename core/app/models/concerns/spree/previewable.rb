module Spree
  module Previewable
    extend ActiveSupport::Concern

    included do |base|
      belongs_to :parent, class_name: base.name, optional: true, foreign_key: :parent_id
      has_many :previews, class_name: base.name, dependent: :destroy_async, foreign_key: :parent_id

      scope :without_previews, -> { where(parent_id: nil) }
      scope :only_previews, -> { where.not(parent_id: nil) }
    end

    def preview?
      parent.present?
    end
  end
end
