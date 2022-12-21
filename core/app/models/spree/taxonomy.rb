module Spree
  class Taxonomy < Spree::Base
    include Metadata
    if defined?(Spree::Webhooks)
      include Spree::Webhooks::HasWebhooks
    end

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
      return unless saved_change_to_name?
      return if name.to_s == root.name.to_s

      root.update(name: name)
    end
  end
end
