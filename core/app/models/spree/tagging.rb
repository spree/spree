module Spree
  class Tagging < Spree.base_class
    self.table_name = 'spree_taggings'

    belongs_to :tag, class_name: 'Spree::Tag', counter_cache: :taggings_count
    belongs_to :taggable, polymorphic: true

    belongs_to :tagger, polymorphic: true, optional: true

    validates :tag_id, presence: true
    validates :taggable_type, presence: true
    validates :taggable_id, presence: true
    validates :context, presence: true
    validates :tag_id, uniqueness: {
      scope: [:taggable_type, :taggable_id, :context, :tagger_id, :tagger_type]
    }

    scope :by_context, ->(context) { where(context: context.to_s) }
    scope :by_tenant, ->(tenant) { where(tenant: tenant.to_s) }

    after_destroy :remove_unused_tags

    private

    def remove_unused_tags
      tag.destroy if tag.taggings.count.zero?
    end
  end
end
