module Spree
  class Taxonomy < Spree::Base
    include Spree::TranslatableResource
    include Spree::Metadata
    if defined?(Spree::Webhooks::HasWebhooks)
      include Spree::Webhooks::HasWebhooks
    end

    TRANSLATABLE_FIELDS = %i[name].freeze
    translates(*TRANSLATABLE_FIELDS, column_fallback: !Spree.always_use_translations?)

    acts_as_list

    validates :name, presence: true, uniqueness: { case_sensitive: false, allow_blank: true, scope: :store_id }
    validates :store, presence: true

    has_many :taxons, inverse_of: :taxonomy
    has_one :root, -> { where parent_id: nil }, class_name: 'Spree::Taxon', dependent: :destroy
    belongs_to :store, class_name: 'Spree::Store'

    after_create :set_root
    after_update :set_root_taxon_name

    default_scope { order("#{table_name}.position, #{table_name}.created_at") }

    self.whitelisted_ransackable_associations = %w[root]

    private

    def set_root
      self.root ||= Taxon.create!(taxonomy_id: id, name: name)
    end

    def set_root_taxon_name
      return unless saved_changes.key?(:name)
      return if name.to_s == root.name.to_s

      root.update(name: name)
    end
  end
end
