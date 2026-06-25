module Spree
  module Api
    module V3
      module Admin
        module Translations
          # Atomically upserts translations across MANY records of (possibly)
          # different translatable resource types in a single request. Powers
          # the dashboard's combined editors (e.g. an option type + all its
          # option values saved in one go).
          #
          # The body is a flat list of independent registry writes — NOT a
          # nested/parent-owns-children payload. Each entry names its own
          # resource_type + resource_id, so the controller stays free of
          # per-model branching.
          #
          # POST /api/v3/admin/translations/batch
          # Body:
          #   { "translations": [
          #       { "resource_type": "option_type",  "resource_id": "opt_…",
          #         "values": { "de": { "label": "Größe" } } },
          #       { "resource_type": "option_value", "resource_id": "optval_…",
          #         "values": { "de": { "label": "Klein" } } }
          #   ] }
          #
          # All entries succeed or none do — a validation failure on any entry
          # rolls back the whole transaction and returns per-entry detail.
          class BatchesController < Admin::BaseController
            # The batch spans heterogeneous resource types, so a single static
            # scope can't gate it. We verify the API key holds the matching
            # write_<resource> scope for EVERY entry (see require_batch_scopes!),
            # which is stricter than the static check and keeps the audit model.
            skip_scope_check!

            # POST /api/v3/admin/translations/batch
            def create
              entries = batch_params
              return render_empty_batch_error if entries.empty?

              return unless require_batch_scopes!(entries)

              records = []
              ActiveRecord::Base.transaction do
                entries.each_with_index do |entry, index|
                  record = resolve_record!(entry, index)
                  authorize!(:update, record)
                  record.upsert_translations(entry[:values])
                  records << record
                end
              end

              render json: { data: records.map { |record| serialize_translations(record) } }
            rescue BatchEntryError => e
              render_error(
                code: ERROR_CODES[:validation_error],
                message: e.message,
                status: :unprocessable_content,
                details: { translations: { e.index.to_s => [e.message] } }
              )
            rescue ActiveRecord::RecordInvalid => e
              render_validation_error(e.record.errors)
            end

            private

            # Raised when an entry can't be resolved (unknown/non-translatable
            # type, or a record not found in the current store). Carries the
            # entry index so the client can map the error back to a row.
            class BatchEntryError < StandardError
              attr_reader :index

              def initialize(message, index)
                @index = index
                super(message)
              end
            end

            # For API-key callers, require write_<resource> for every distinct
            # resource type in the batch. JWT callers bypass (current_api_key is
            # nil) and rely on the per-record authorize!(:update, record) above.
            # Returns false (and renders 403) when a scope is missing.
            def require_batch_scopes!(entries)
              return true unless current_api_key

              required = entries.map { |e| "write_#{e[:resource_type].pluralize}" }.uniq
              missing = required.reject { |scope| current_api_key.has_scope?(scope) }
              return true if missing.empty?

              render_error(
                code: ERROR_CODES[:access_denied],
                message: "API key lacks scope(s): #{missing.join(', ')}",
                status: :forbidden,
                details: { required_scopes: missing }
              )
              false
            end

            def resolve_record!(entry, index)
              klass = resource_class(entry[:resource_type])
              raise BatchEntryError.new("Unknown translatable resource type: #{entry[:resource_type]}", index) if klass.nil?

              relation = klass.respond_to?(:for_store) ? klass.for_store(current_store) : klass
              relation.find_by_prefix_id!(entry[:resource_id])
            rescue ActiveRecord::RecordNotFound
              raise BatchEntryError.new("Resource not found: #{entry[:resource_id]}", index)
            end

            # Resolve via a request-memoized map so a batch of N entries doesn't
            # rebuild the registry map N times. Fresh per request, so dev-mode
            # class reloads are still picked up.
            def resource_class(token)
              @resource_class_map ||= Hash.new { |h, t| h[t] = Spree::Translations::Matrix.resource_class(t) }
              @resource_class_map[token]
            end

            # [{ resource_type:, resource_id:, values: { locale => { field => value } } }]
            def batch_params
              Array(params[:translations]).map do |entry|
                permitted = entry.respond_to?(:permit) ? entry.permit(:resource_type, :resource_id, values: {}) : entry
                values = permitted[:values]
                {
                  resource_type: permitted[:resource_type].to_s,
                  resource_id: permitted[:resource_id].to_s,
                  values: values.respond_to?(:to_unsafe_h) ? values.to_unsafe_h : (values || {}).to_h
                }
              end
            end

            def render_empty_batch_error
              render_error(
                code: ERROR_CODES[:validation_error],
                message: 'translations must be a non-empty array',
                status: :unprocessable_content
              )
            end

            def serialize_translations(record)
              {
                resource_type: Spree::Translations::Matrix.resource_type(record.class),
                resource_id: record.prefixed_id,
                default_locale: current_store.default_locale,
                supported_locales: current_store.supported_locales_list,
                translations: Spree::Translations::Matrix.for(record)
              }
            end

            def action_kind
              'write'
            end
          end
        end
      end
    end
  end
end
