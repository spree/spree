module Spree
  module Api
    module V3
      module Admin
        # See `docs/plans/5.5-admin-spa-csv-export.md`.
        class ExportsController < ResourceController
          include ActiveStorage::SetCurrent

          scoped_resource :exports

          # We stream the CSV inline rather than redirecting to ActiveStorage's
          # signed-URL endpoint because the SPA's Vite proxy only forwards
          # `/api/*`. A cross-origin redirect to `/rails/active_storage/...`
          # strips the Authorization header and the download fails silently.
          def download
            @resource = find_resource
            authorize_resource!(@resource, :show)

            unless @resource.done?
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:export_not_ready],
                message: 'Export is not ready yet',
                status: :unprocessable_content
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

          def scope_includes
            [:user, { attachment_attachment: :blob }]
          end

          def build_resource
            klass = resolve_export_type(permitted_params[:type]) || Spree::Export
            attrs = permitted_params.except(:type).merge(
              store: current_store,
              user: try_spree_current_user
            )
            klass.new(attrs)
          end

          # `search_params` carries an arbitrary Ransack hash with nested
          # groupings (`{ g: [{ name_cont: 'foo' }] }`). Rails' `permit(k: {})`
          # rejects nested hashes, so we extract via `to_unsafe_h`. `:format`
          # is intentionally dropped — only CSV is supported and Rails' request
          # format would otherwise overwrite the model's enum.
          def permitted_params
            attrs = params.permit(:type, :record_selection)
            raw = params[:search_params]
            attrs[:search_params] = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw if raw.present?
            attrs
          end

          # Returns the registered Export subclass matching `name`, or nil.
          #
          # The constantize target comes from `available_types` (a trusted
          # in-process registry), not from the request — `name` is only used
          # to *select* an entry in the allowlist. This keeps the data flow
          # from user input → trusted-string → `constantize` legible to
          # static analyzers (CodeQL otherwise flags the inverse pattern of
          # gating user input with `include?` before calling `constantize`).
          def resolve_export_type(name)
            return nil if name.blank?

            target = Spree::Export.available_types.map(&:to_s).find { |t| t == name.to_s }
            target&.constantize
          end
        end
      end
    end
  end
end
