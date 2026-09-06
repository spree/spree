module Spree
  module Exports
    # CSV of one reporting query (docs/plans/6.0-analytics-semantic-layer.md).
    # `search_params` carries `{ "query" => <contract JSON> }`; the rows are the
    # compiled result plus a totals line. Runs as the requesting user so the
    # query is authorized member-by-member exactly like the API — which is
    # why a user is required (API keys cannot queue report exports).
    class Report < Spree::Export
      validates :user, presence: true
      # Refuse now what the background job would refuse later: a query that
      # does not compile, or a member the requesting user may not read, must
      # be a 422 the caller sees rather than an export that never becomes done.
      validate :query_must_compile_and_be_readable, on: :create, if: -> { user.present? }

      def self.required_scope
        :reports
      end

      # Not a bulk export of a model — the derived `Spree::Report` (legacy CSV
      # reports) would be wrong, so anchor on the saved-report model instead.
      def self.model_class
        Spree::SavedReport
      end

      def model_class
        self.class.model_class
      end

      def csv_headers
        labels = Spree::Reporting::Schema.new(store: store)
        dimension_labels = reporting_query.dimensions.map { |d| labels.label_for(:dimensions, d[:dimension].name) }
        metric_labels = reporting_query.metrics.map { |m| labels.label_for(:metrics, m.name) }
        dimension_labels + metric_labels
      end

      def generate_csv
        query = reporting_query
        authorize_members!(query)
        result = query.execute

        # Labels, not group keys: the file must read like the screen, so a
        # channel column says "Web", never the channel's database id.
        hydration = Spree::Reporting::Hydration.new(result, store: store)

        ::CSV.open(export_tmp_file_path, 'wb', encoding: 'UTF-8', col_sep: ',', row_sep: "\r\n") do |csv|
          csv << csv_headers
          result.rows.each do |row|
            csv << Spree::CSV::FormulaSanitizer.row(
              row[:dimensions].map { |name, raw| hydration.label(name, raw) } +
                query.metrics.map { |m| row[:metrics][m.name][:value] }
            )
          end
          totals = query.metrics.map { |m| result.totals[m.name][:value] }
          # With a breakdown the totals close the file under a "Total" label in
          # the first dimension column; without one the totals are the only row.
          label = query.dimensions.empty? ? [] : [Spree.t('reporting.export.total')] + Array.new(query.dimensions.size - 1, '')
          csv << Spree::CSV::FormulaSanitizer.row(label + totals)
        end
      end

      private

      def reporting_query
        @reporting_query ||= Spree::Reporting::Query.new(store: store, params: query_params)
      end

      def query_params
        raw = search_params.is_a?(String) ? JSON.parse(search_params) : (search_params || {})
        raise Spree::Reporting::InvalidQuery, 'search_params must be an object' unless raw.is_a?(Hash)

        raw['query'] || raw[:query] || {}
      end

      def authorize_members!(query)
        forbidden = query.unreadable_subjects(current_ability).first
        raise CanCan::AccessDenied.new(nil, :read, forbidden) if forbidden
      end

      def query_must_compile_and_be_readable
        errors.add(:base, :forbidden_reporting_member) if reporting_query.unreadable_subjects(current_ability).any?
      rescue Spree::Reporting::UnknownMember, Spree::Reporting::InvalidQuery => e
        errors.add(:search_params, :invalid_reporting_query, message: e.message)
      rescue JSON::ParserError
        errors.add(:search_params, :invalid)
      end
    end
  end
end
