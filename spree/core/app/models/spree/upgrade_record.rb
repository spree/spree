module Spree
  # A release boundary whose data steps this installation has completed
  # (docs/plans/6.0-maintenance-tasks.md).
  #
  # This exists because nothing else in the schema records where an
  # installation upgraded *from*. `Spree.version` is only ever the gem that is
  # installed now, so without a stamp the dashboard cannot tell a store that
  # has been on 5.6 for months from one jumping straight from 5.4 — and would
  # have to show both every step of every manifest, which grows with each
  # release.
  #
  # Written from three places, none of which guesses:
  #
  # - a successful `spree:upgrade` walk stamps the boundary it reached
  # - a fresh install stamps the current version, because a database created
  #   by today's schema has no historical data to convert
  # - an operator can stamp one by hand, for a store upgraded before this
  #   record existed
  class UpgradeRecord < Spree.base_class
    has_prefix_id :upg

    include Spree::Metadata

    SOURCES = %w[walk install manual].freeze

    validates :version, presence: true, uniqueness: true
    validates :source, presence: true, inclusion: { in: SOURCES }
    validates :completed_at, presence: true

    # Whether this installation has ever been upgraded, as opposed to having
    # been installed at its current version.
    #
    # A store installed fresh at 6.0 has no historical data to convert and no
    # upgrade to perform — showing it a manifest of steps, current or past,
    # describes work that does not exist for it.
    #
    # @return [Boolean]
    def self.upgraded?
      where.not(source: 'install').exists?
    end

    # The highest boundary recorded, or nil when this installation has never
    # stamped one.
    #
    # @return [String, nil]
    def self.current_version
      all.map(&:version).max_by { |version| Spree::Upgrade.version_parts(version) }
    end

    # Records a completed boundary. Idempotent — re-running a walk that has
    # already been stamped updates when it happened rather than failing.
    #
    # @param version [String] two-segment release, e.g. "6.0"
    # @param source [String] one of SOURCES
    # @return [Spree::UpgradeRecord]
    def self.stamp!(version, source: 'walk', metadata: {})
      record = find_or_initialize_by(version: version.to_s)
      record.source = source.to_s
      record.completed_at = Time.current
      record.metadata = (record.metadata || {}).merge(metadata)
      record.save!
      record
    end
  end
end
