module Spree
  module Api
    module V3
      module Admin
        # See `docs/plans/5.5-admin-spa-csv-export.md`.
        #
        # There is no standalone exports scope: an export is a bulk read of
        # the records it contains, so each export type is gated by the read
        # scope of the exported resource (Spree::Exports::Customers =>
        # `read_customers`; see Spree::Export.required_scope), and the index
        # is filtered to the types the key can read.
        class ExportsController < ResourceController
          include ActiveStorage::SetCurrent

          # The index spans many export types — `scope` filters it to the
          # readable ones instead of gating on a single scope.
          skip_scope_check! only: :index

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

          def scope
            collection = super
            return collection unless scope_limited_principal?

            collection.where(type: readable_export_types)
          end

          # Loaded by both the scope gate (before_action) and the member
          # actions — memoize so the record is fetched once.
          def find_resource
            @find_resource ||= super
          end

          # Exports never mutate commerce data; creating or downloading one
          # is a bulk read, so every action maps to the read-level scope.
          def action_kind
            'read'
          end

          # Unresolvable types (blank/unknown `type` on create) fall back to
          # `:all`, so only `read_all`/`write_all` keys reach the model's own
          # validation.
          def scoped_resource_name
            export_class&.required_scope || :all
          end

          def build_resource
            klass = resolve_export_type(permitted_params[:type]) || Spree::Export
            attrs = permitted_params.except(:type).merge(
              store: current_store,
              user: try_spree_current_user
            )
            attrs[:results_url] = validated_results_url(attrs[:results_url])
            klass.new(attrs)
          end

          # `search_params` carries an arbitrary Ransack hash with nested
          # groupings (`{ g: [{ name_cont: 'foo' }] }`). Rails' `permit(k: {})`
          # rejects nested hashes, so we extract via `to_unsafe_h`. `:format`
          # is intentionally dropped — only CSV is supported and Rails' request
          # format would otherwise overwrite the model's enum.
          def permitted_params
            attrs = params.permit(:type, :record_selection, :results_url)
            raw = params[:search_params]
            attrs[:search_params] = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw if raw.present?
            attrs
          end

          # The export-done email links to this URL (typically the caller's
          # own exports view). Only honored when it matches a configured
          # allowed origin — otherwise silently dropped and the email renders
          # no download button. Mirrors ImportsController#validated_results_url.
          def validated_results_url(url)
            return if url.blank?
            return unless current_store.allowed_origins.exists? && current_store.allowed_origin?(url)

            url
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

          private

          def export_class
            action_name == 'create' ? resolve_export_type(params[:type]) : find_resource.class
          end

          def readable_export_types
            Spree::Export.available_types.select do |type|
              required = type.required_scope
              required ? current_api_key.has_scope?("read_#{required}") : current_api_key.has_scope?('read_all')
            end.map(&:to_s)
          end
        end
      end
    end
  end
end
