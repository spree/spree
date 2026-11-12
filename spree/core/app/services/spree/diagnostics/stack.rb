module Spree
  class Diagnostics
    # The installation's stack and rough size, shared by the update check's
    # heartbeat and the diagnostics report so the two never describe the same
    # installation differently.
    module Stack
      # Order-of-magnitude buckets: enough to tell a hobby install from a large
      # merchant, never an exact figure.
      BUCKETS = {
        0..0 => '0',
        1..9 => '1-9',
        10..99 => '10-99',
        100..999 => '100-999',
        1_000..9_999 => '1k-9k',
        10_000..99_999 => '10k-99k'
      }.freeze
      LARGEST_BUCKET = '100k+'.freeze
      SPREE_URL = %r{\Ahttps?://(www\.)?(spreecommerce\.org|github\.com/spree/)}

      module_function

      # @return [String] the database adapter, e.g. +postgresql+
      def database
        ActiveRecord::Base.connection_db_config.adapter
      end

      # Spree's own gems and published Spree extensions, by name. A private
      # gem named spree_* is left out: its name is the merchant's business.
      #
      # @return [Hash{String => String}] gem name => version
      def spree_gems
        Gem.loaded_specs.values.select { |spec| spree_gem?(spec) && public_gem?(spec) }.
          sort_by(&:name).to_h { |spec| [spec.name, spec.version.to_s] }
      end

      # @param spec [Gem::Specification]
      # @return [Boolean]
      def spree_gem?(spec)
        spec.name == 'spree' || spec.name.start_with?('spree_')
      end

      # Whether a gem's name can appear in a public bug report: one of Spree's
      # own, or one installed from rubygems.org. Gems from a path, git or a
      # private gem server are often the merchant's own code.
      #
      # @param spec [Gem::Specification]
      # @return [Boolean]
      def public_gem?(spec)
        return true if [spec.homepage, *spec.metadata.values].any? { |url| url.to_s.match?(SPREE_URL) }

        source = spec.respond_to?(:source) ? spec.source : nil
        source.is_a?(Bundler::Source::Rubygems) && source.remotes.all? { |remote| remote.host == 'rubygems.org' }
      end

      # @return [Boolean] whether this installation serves an admin dashboard
      def dashboard_served?
        (defined?(Spree::Dashboard) && Spree::Dashboard.dist_path.present?) || Spree::Config.dashboard_url.present?
      end

      # @param count [Integer]
      # @return [String]
      def bucket(count)
        BUCKETS.find { |range, _| range.cover?(count) }&.last || LARGEST_BUCKET
      end

      # @return [String, nil] nil when the installation has no sellers
      def seller_bucket
        count = Spree::Seller.count
        bucket(count) if count.positive?
      end
    end
  end
end
