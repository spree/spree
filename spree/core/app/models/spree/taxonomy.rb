module Spree
  # @deprecated Data-only in 6.0. Categories are store-owned via +store_id+ and
  #   nothing creates or reads a taxonomy at runtime any more. The model and the
  #   spree_taxonomies table are retained solely so the 5.6 -> 6.0 upgrade task
  #   (spree:migrate_categories_and_collections) can read existing rows to
  #   backfill category store_id, and so an interrupted upgrade can be rolled
  #   back. Both drop in 6.1.
  class Taxonomy < Spree.base_class
    has_prefix_id :txnmy  # Spree-specific: taxonomy

    include Spree::SingleStoreResource

    has_many :taxons, class_name: 'Spree::Category', inverse_of: :taxonomy
    has_one :root, -> { where parent_id: nil }, class_name: 'Spree::Category', dependent: :destroy
    belongs_to :store, class_name: 'Spree::Store'

    default_scope { order("#{table_name}.position, #{table_name}.created_at") }
  end
end
