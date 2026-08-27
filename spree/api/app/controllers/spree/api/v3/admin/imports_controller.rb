module Spree
  module Api
    module V3
      module Admin
        # See `docs/plans/5.6-admin-spa-csv-import.md`.
        #
        # There is no standalone imports scope: an import is a bulk write of
        # the records it creates, so every action — including reads, which
        # expose the uploaded data — maps to the write scope of the imported
        # resource (Spree::Imports::Customers => `write_customers`; see
        # Spree::Import.required_scope). The index is filtered to the types
        # the key can write.
        class ImportsController < ResourceController
          include ActiveStorage::SetCurrent

          # The index spans many import types — `scope` filters it to the
          # writable ones instead of gating on a single scope.
          skip_scope_check! only: :index

          # POST /api/v3/admin/imports
          #
          # `attachment` is an ActiveStorage signed blob id obtained from
          # POST /api/v3/admin/direct_uploads. On success the import advances
          # straight into `mapping` (auto-assigning file columns from the CSV
          # headers), so the response already carries the mapping payload.
          def create
            @resource = build_resource
            authorize_resource!(@resource, :create)

            if @resource.save
              begin
                result = Spree.import_start_mapping_workflow.call(import: @resource)

                return render_service_error(result.error) unless result.success?
              rescue ::CSV::MalformedCSVError, EncodingError => e
                @resource.update_columns(status: 'failed', processing_errors: e.message, updated_at: Time.current)
                return render_error(
                  code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                  message: "Could not parse CSV: #{e.message}",
                  status: :unprocessable_content
                )
              end

              render json: serialize_resource(@resource), status: :created
            else
              render_errors(@resource.errors)
            end
          rescue ActiveSupport::MessageVerifier::InvalidSignature
            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
              message: 'Invalid attachment signed id',
              status: :unprocessable_content
            )
          end

          # PATCH /api/v3/admin/imports/:id/complete_mapping
          #
          # Applies the submitted mappings atomically, then transitions out of
          # mapping (which enqueues row creation + processing). 422 when
          # required schema fields remain unmapped or a file column is
          # assigned twice.
          def complete_mapping
            @resource = find_resource
            authorize_resource!(@resource, :update)

            unless @resource.mapping?
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: 'Import is not in the mapping state',
                status: :unprocessable_content
              )
            end

            apply_mappings!(@resource)

            if @resource.mapping_done?
              result = Spree.import_complete_mapping_workflow.call(import: @resource)

              return render_service_error(result.error) unless result.success?

              render json: serialize_resource(@resource)
            else
              missing = @resource.required_fields - @resource.mappings.mapped.pluck(:schema_field)
              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: "Required fields are not mapped: #{missing.join(', ')}",
                status: :unprocessable_content,
                details: { missing_required_fields: missing }
              )
            end
          rescue ActiveRecord::RecordInvalid => e
            render_validation_error(e.record.errors)
          end

          # PATCH /api/v3/admin/imports/:id/retry_failed_rows
          #
          # Re-dispatches processing over the rows still `failed` (the
          # dispatcher's pending_and_failed scope picks them up). 422 unless
          # the import is `completed` with failures.
          def retry_failed_rows
            @resource = find_resource
            authorize_resource!(@resource, :update)

            return if refuse_seller_owned!

            result = Spree.import_retry_failed_rows_workflow.call(import: @resource)

            if result.success?
              render json: serialize_resource(@resource)
            else
              render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: 'Import has no failed rows to retry',
                status: :unprocessable_content
              )
            end
          end

          # GET /api/v3/admin/imports/:id/download
          #
          # Streams the originally uploaded CSV — the audit trail for what
          # was actually imported. Same inline-streaming rationale as
          # ExportsController#download: a signed ActiveStorage URL neither
          # survives the SPA's `/api/*`-only dev proxy nor carries the JWT.
          def download
            @resource = find_resource
            authorize_resource!(@resource, :show)

            attachment = @resource.attachment
            unless attachment.attached?
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: 'Import has no attached file',
                status: :unprocessable_content
              )
            end

            send_data(
              attachment.download,
              filename: attachment.filename.to_s,
              type: attachment.content_type || 'text/csv',
              disposition: 'attachment'
            )
          end

          # GET /api/v3/admin/imports/template?type=Spree::Imports::Products
          #
          # CSV header row for the type's schema (including the custom_field
          # columns available for the model) — the "Download template" link
          # in the admin dashboard.
          def template
            klass = resolve_import_type(params[:type])

            unless klass
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
                message: 'Unknown import type',
                status: :unprocessable_content
              )
            end

            import = klass.new
            send_data import.template_csv,
                      filename: import.template_csv_filename,
                      type: 'text/csv',
                      disposition: 'attachment'
          end

          # GET /api/v3/admin/imports/example?type=products
          #
          # Redirects to the populated example CSV for the type — the counterpart
          # to `template` above. 404s for a type that ships no example file.
          #
          # The client can't build this URL itself: it is pinned to the
          # installed Spree version, and exposing that version over the API
          # would fingerprint the deployment for anyone matching CVEs. Resolving
          # it here keeps the version server-side.
          def example
            klass = resolve_import_type(params[:type])
            url = klass&.sample_csv_url

            unless url
              return render_error(
                code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:record_not_found],
                message: 'No example CSV for this import type',
                status: :not_found
              )
            end

            redirect_to url, allow_other_host: true, status: :found
          end

          # DELETE /api/v3/admin/imports/:id
          #
          # An operator deletes their own imports. A seller's is theirs to
          # remove — see `refuse_seller_owned!`.
          def destroy
            @resource = find_resource
            authorize_resource!(@resource, :destroy)

            return if refuse_seller_owned!

            super
          end

          protected

          def model_class
            Spree::Import
          end

          def serializer_class
            Spree.api.admin_import_serializer
          end

          def scope_includes
            [:user, :mappings, { attachment_attachment: :blob }]
          end

          def scope
            collection = super
            return collection unless scope_limited_principal?

            collection.where(type: writable_import_types)
          end

          # Loaded by both the scope gate (before_action) and the member
          # actions — memoize so the record is fetched once.
          def find_resource
            @find_resource ||= super
          end

          # Every action on an import maps to the write scope of the imported
          # resource: creating is a bulk write, and status/rows expose the
          # uploaded data, so read-only keys get nothing.
          def action_kind
            'write'
          end

          # Unresolvable types (blank/unknown `type` on create/template) fall
          # back to `:all`, so only `write_all` keys reach the model's own
          # validation.
          def scoped_resource_name
            import_class&.required_scope || :all
          end

          def build_resource
            klass = resolve_import_type(permitted_params[:type]) || Spree::Import
            attrs = permitted_params.except(:type).merge(
              store: current_store,
              user: acting_admin_user
            )
            # The done email links back to results_url — allowed origins only.
            attrs[:results_url] = validated_allowed_origin_url(attrs[:results_url])
            klass.new(attrs)
          end

          def permitted_params
            params.permit(*model_additional_permitted_attributes, :type, :attachment, :preferred_delimiter, :results_url)
          end

          # Returns the registered Import subclass matching `name`, or nil.
          #
          # Takes the API shorthand (`"products"`), the same value the
          # serializer emits. The fully-qualified class name is also accepted so
          # a `type` read back from the API round-trips either way.
          #
          # The class comes from `available_types` (a trusted in-process
          # registry), not from the request — `name` is only used to *select* an
          # entry in the allowlist (same pattern as
          # ExportsController#resolve_export_type).
          def resolve_import_type(name)
            return nil if name.blank?

            name = name.to_s
            Spree::Import.available_types.find { |type| type.api_type == name || type.to_s == name }
          end

          private

          # Refuses a write against an import one of this store's sellers ran,
          # rendering 422 and answering true so the caller returns.
          #
          # An operator can see every import in their marketplace — that is the
          # point of the store-scoped list, and it is what makes a seller's
          # failed rows debuggable. Acting on one is different: a retry re-runs
          # writes into the seller's own catalog, and nothing on the import
          # would record that the operator, rather than the seller, caused
          # them. So reads span the store and writes stay with whoever owns the
          # row.
          #
          # @return [Boolean]
          def refuse_seller_owned!
            return false if @resource.seller_id.blank?

            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
              message: Spree.t(:cannot_modify_seller_import, scope: 'api',
                               default: "This import belongs to a seller. It can be viewed here, but only the seller can retry or delete it."),
              status: :unprocessable_content
            )
            true
          end

          # Imports require a user: row processors resolve records through
          # `import.current_ability`. JWT requests use the signed-in admin;
          # API-key requests attribute to the key's creator when that is an
          # admin user, otherwise the model's presence validation renders 422.
          def acting_admin_user
            return try_spree_current_user if try_spree_current_user

            created_by = current_api_key&.created_by
            created_by if created_by.is_a?(Spree.admin_user_class)
          end

          def import_class
            case action_name
            when 'create', 'template', 'example' then resolve_import_type(params[:type])
            else find_resource.class
            end
          end

          def writable_import_types
            Spree::Import.available_types.select do |type|
              required = type.required_scope
              required ? current_api_key.has_scope?("write_#{required}") : current_api_key.has_scope?('write_all')
            end.map(&:to_s)
          end

          def apply_mappings!(import)
            submitted = params[:mappings]
            return if submitted.blank?

            ApplicationRecord.transaction do
              submitted.each do |entry|
                mapping = import.mappings.find_by(schema_field: entry[:schema_field])
                next unless mapping

                mapping.update!(file_column: entry[:file_column].presence)
              end
            end
            import.mappings.reload
          end
        end
      end
    end
  end
end
