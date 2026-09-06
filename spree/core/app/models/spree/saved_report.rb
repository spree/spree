module Spree
  # A reporting query kept for reuse: the contract JSON (see
  # Spree::Reporting::Query); its visualization is inferred from the query's
  # shape. Owned by the store and visible to every staff member who may read
  # reports; the author is recorded for attribution only — execution
  # re-authorizes the viewer.
  class SavedReport < Spree.base_class
    has_prefix_id :sq

    include Spree::SingleStoreResource

    publishes_lifecycle_events

    belongs_to :user, class_name: Spree.admin_user_class.to_s, optional: true

    validates :name, presence: true, uniqueness: { scope: spree_base_uniqueness_scope + [:store_id], case_sensitive: false }
    validates :query, presence: true
    validate :query_must_compile
    # A built-in report is a fixed reference point: it can be copied or
    # deleted, never edited in place — the same rule the dashboard shows.
    validate :seeded_reports_are_read_only, on: :update

    scope :seeded, -> { where(seeded: true) }

    self.whitelisted_ransackable_attributes = %w[name seeded created_at updated_at]

    def event_serializer_class
      'Spree::Api::V3::Admin::SavedReportSerializer'.safe_constantize
    end

    # The stored query, normalized against the registry.
    #
    # @return [Spree::Reporting::Query]
    def reporting_query
      Spree::Reporting::Query.new(store: store, params: query || {})
    end

    private

    # Refuse to save a query the registry cannot compile — a report must never
    # 422 the day it is opened.
    def query_must_compile
      return if store.blank? || query.blank?

      reporting_query
    rescue Spree::Reporting::UnknownMember, Spree::Reporting::InvalidQuery => e
      errors.add(:query, :invalid_reporting_query, message: e.message)
    end

    def seeded_reports_are_read_only
      return unless seeded_was && (changed & %w[name description query]).any?

      errors.add(:base, :seeded_report_read_only)
    end
  end
end
