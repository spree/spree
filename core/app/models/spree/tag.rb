module Spree
  class Tag < Spree.base_class
    include Spree::RansackableAttributes

    self.table_name = 'spree_tags'

    has_many :taggings, class_name: 'Spree::Tagging', dependent: :destroy

    validates :name, presence: true, uniqueness: { scope: spree_base_uniqueness_scope, case_sensitive: false }

    self.whitelisted_ransackable_attributes = %w[id name]
    self.whitelisted_ransackable_associations = %w[taggings]

    scope :named, ->(name) { where('LOWER(name) = ?', name.to_s.downcase.strip) }
    scope :named_any, ->(list) { where('LOWER(name) IN (?)', list.map { |n| n.to_s.downcase.strip }) }
    scope :named_like, ->(name) { where('LOWER(name) LIKE ?', "%#{name.to_s.downcase.strip}%") }
    scope :named_like_any, ->(list) { where(list.map { |n| arel_table[:name].lower.matches("%#{n.to_s.downcase.strip}%") }.reduce(:or)) }

    # Filter tags by context
    scope :for_context, ->(context) {
      joins(:taggings).where(Spree::Tagging.table_name => { context: context.to_s }).distinct
    }

    # Filter tags by tenant (e.g., store_id)
    scope :for_tenant, ->(tenant) {
      joins(:taggings).where(Spree::Tagging.table_name => { tenant: tenant.to_s }).distinct
    }

    # Find or create a tag by name (case-insensitive)
    def self.find_or_create_with_like_by_name(name)
      named(name).first || create(name: name.to_s.strip)
    end

    # Find or create all tags from a list of names
    def self.find_or_create_all_with_like_by_name(*list)
      list = [list].flatten.compact.map(&:to_s).map(&:strip).reject(&:blank?)

      return [] if list.empty?

      existing = named_any(list).index_by { |t| t.name.downcase }

      list.map do |name|
        existing[name.downcase] || create!(name: name)
      end
    end

    def ==(other)
      super || (other.is_a?(Tag) && name.downcase == other.name.downcase)
    end

    def to_s
      name
    end
  end
end
