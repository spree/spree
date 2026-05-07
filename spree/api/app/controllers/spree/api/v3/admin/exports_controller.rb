module Spree
  module Api
    module V3
      module Admin
        # CSV exports for products, orders, customers, etc. Mirrors the legacy
        # `Spree::Admin::ExportsController` modal flow: `type` selects the
        # `Spree::Export` subclass, `search_params` carries a Ransack hash from
        # the SPA's filter state, and `record_selection: 'all'` opts out of
        # filtering on the server. Generation runs in
        # {Spree::Exports::GenerateJob} via the `export.create` event; the SPA
        # polls `show` until `done` flips to `true`.
        #
        # See `docs/plans/5.5-admin-spa-csv-export.md`.
        class ExportsController < ResourceController
          include ActiveStorage::SetCurrent

          scoped_resource :exports

          # GET /api/v3/admin/exports/:id/download
          #
          # Authorizes via the standard ResourceController stack (JWT or API
          # key with `read_exports` scope), then streams the CSV inline.
          #
          # We deliberately do NOT redirect to ActiveStorage's signed-URL
          # endpoint: the SPA's dev proxy only forwards `/api/*`, so a
          # cross-origin redirect to `/rails/active_storage/...` strips the
          # Authorization header and breaks downloads. Streaming keeps the
          # entire transfer under `/api/*` in every deployment topology.
          def download
            @resource = find_resource
            authorize_resource!(@resource, :show)

            unless @resource.done?
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:not_found],
                message: 'Export is not ready yet',
                status: :not_found
              )
            end

            attachment = @resource.attachment
            send_data(
              attachment.download,
              filename: attachment.filename.to_s,
              type: attachment.content_type || 'text/csv',
              disposition: 'attachment'
            )
          end

          protected

          def model_class
            Spree::Export
          end

          def serializer_class
            Spree.api.admin_export_serializer
          end

          def collection_includes
            [:user, { attachment_attachment: :blob }]
          end

          def scope_includes
            [{ attachment_attachment: :blob }]
          end

          # The persisted row is one of the registered subclasses (e.g.
          # `Spree::Exports::Products`), not the `Spree::Export` parent. We
          # resolve the class from the `type` param against the configured
          # allowlist so we can't be tricked into instantiating an arbitrary
          # constant from an API request.
          def build_resource
            klass = resolve_export_type(permitted_params[:type]) || Spree::Export
            attrs = permitted_params.except(:type).merge(
              store: current_store,
              user: try_spree_current_user
            )
            klass.new(attrs)
          end

          # `search_params` is an arbitrary Ransack hash that can include
          # nested groupings (`{ g: [{ name_cont: 'foo' }] }`). Rails'
          # `permit(key: {})` only allows scalar values inside the hash, so we
          # extract it via `to_unsafe_h` instead. The Export model's
          # `normalize_search_params` callback handles JSON conversion and
          # malformed input.
          #
          # `:format` is intentionally not accepted from the request — only
          # CSV is supported (Spree::Export::SUPPORTED_FILE_FORMATS), and
          # Rails' request format would otherwise leak into the assignment.
          def permitted_params
            attrs = params.permit(:type, :record_selection)
            raw = params[:search_params]
            attrs[:search_params] = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw if raw.present?
            attrs
          end

          def resolve_export_type(name)
            return nil if name.blank?

            allowed = Spree::Export.available_types.map(&:to_s)
            return nil unless allowed.include?(name.to_s)

            name.to_s.safe_constantize
          end
        end
      end
    end
  end
end
