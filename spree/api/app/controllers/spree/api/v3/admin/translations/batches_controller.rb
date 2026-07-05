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
          # The orchestration (resolve → upsert → rollback) lives in
          # Spree::Translations::Batch; the controller only handles params,
          # authorization, and rendering.
          class BatchesController < Admin::BaseController
            # The batch spans heterogeneous resource types, so a single static
            # scope can't gate it. We verify the API key holds the matching
            # write_<resource> scope for EVERY entry (see require_batch_scopes!),
            # which is stricter than the static check and keeps the audit model.
            skip_scope_check!

            # POST /api/v3/admin/translations/batch
            def create
              raw = params[:translations]
              return render_empty_batch_error unless raw.is_a?(Array) && raw.any?

              batch = Spree::Translations::Batch.new(batch_params)
              return unless require_batch_scopes!(batch)

              records = batch.process! { |record| authorize!(:update, record) }
              render json: { data: records.map { |record| serialize_translations(record) } }
            rescue Spree::Translations::Batch::EntryError => e
              render_error(
                code: ERROR_CODES[:validation_error],
                message: e.message,
                status: :unprocessable_content,
                details: { translations: { e.index.to_s => [e.message] } }
              )
            end

            private

            # For API-key callers, require write_<resource> for every distinct
            # resource type in the batch. JWT callers bypass (current_api_key is
            # nil) and rely on the per-record authorize!(:update, record) above.
            # Returns false (and renders 403) when a scope is missing.
            def require_batch_scopes!(batch)
              return true unless current_api_key

              missing = batch.required_scopes.reject { |scope| current_api_key.has_scope?(scope) }
              return true if missing.empty?

              render_error(
                code: ERROR_CODES[:access_denied],
                message: "API key lacks scope(s): #{missing.join(', ')}",
                status: :forbidden,
                details: { required_scopes: missing }
              )
              false
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

            # Write echo: matrix + locale envelope, no discovery fields/children.
            def serialize_translations(record)
              Spree.api.admin_resource_translations_serializer.new(
                record, params: serializer_params.merge(fields: false, envelope: true)
              ).to_h
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
