module Spree
  module Api
    module V3
      module Seller
        # A seller's own CSV imports — bulk-listing their catalog rather than
        # typing each product into the form.
        #
        # The pipeline is the operator's, unchanged: the same upload, the same
        # column mapping, the same row processors. What differs is ownership
        # and reach, and both are decided outside this controller — the import
        # is created carrying `seller: current_seller`, and
        # `Spree::Imports::RowProcessors::ProductVariant` reads that owner to
        # narrow which products a row may resolve onto and to stamp the seller
        # on the ones it creates. That narrowing cannot live here: rows are
        # processed in a background job, long after any request scope is gone.
        #
        # Products only. Customers belong to the marketplace, and translations
        # of the catalog's copy are its merchandising — the same line the
        # seller products endpoint already draws around tags and categories.
        #
        # Imported products land as `draft` whatever the CSV's status column
        # says; a seller reaches `active` only through review
        # (docs/plans/6.0-seller-product-submission.md).
        class ImportsController < Seller::ResourceController
          include ActiveStorage::SetCurrent

          # The import types a seller may run. An operator's `customers` or
          # `product_translations` upload is not theirs to start, so it is not
          # merely hidden — a `type` outside this list resolves to nothing and
          # the create fails the model's own whitelist.
          PERMITTED_TYPES = ['Spree::Imports::Products'].freeze

          scoped_resource :products

          # POST /api/v3/seller/imports
          #
          # `attachment` is an ActiveStorage signed blob id from
          # POST /api/v3/seller/direct_uploads. On success the import is
          # already in `mapping`, carrying the auto-assigned columns.
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

          # PATCH /api/v3/seller/imports/:id/complete_mapping
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

          # PATCH /api/v3/seller/imports/:id/retry_failed_rows
          def retry_failed_rows
            @resource = find_resource
            authorize_resource!(@resource, :update)

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

          # GET /api/v3/seller/imports/:id/download
          #
          # The originally uploaded CSV — what the seller actually sent.
          # Streamed inline for the same reason the operator's twin is: a
          # signed ActiveStorage URL neither survives the panel's `/api/*`-only
          # dev proxy nor carries the JWT.
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

          # GET /api/v3/seller/imports/template?type=products
          def template
            klass = resolve_import_type(params[:type])

            return render_unknown_type unless klass

            import = klass.new
            send_data import.template_csv,
                      filename: import.template_csv_filename,
                      type: 'text/csv',
                      disposition: 'attachment'
          end

          # GET /api/v3/seller/imports/example?type=products
          #
          # Redirects to the populated example CSV. The panel cannot build this
          # URL itself: it is pinned to the installed Spree version, and
          # exposing that version would fingerprint the deployment.
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

          protected

          def model_class
            Spree::Import
          end

          def serializer_class
            Spree.api.seller_import_serializer
          end

          def scope_includes
            [:user, :mappings, { attachment_attachment: :blob }]
          end

          # `Spree::Seller` has no `imports` association to read through, so
          # the root scope is stated here rather than inherited: this seller's
          # own rows, and only the types they are allowed to run — an import
          # created before a type was withdrawn stays out of the list.
          #
          # The eager loads are applied by hand for the same reason: the
          # inherited implementations attach them to the association they root
          # in, and the serializer reads each import's blob and mappings, so
          # without them the index issues a query per row.
          def scope
            Spree::Import.for_store(current_store).
              for_seller(current_seller).
              where(type: PERMITTED_TYPES).
              includes(scope_includes).
              preload_associations_lazily
          end

          def resource_scope
            scope
          end

          # Memoized so a member action that both authorizes and renders the
          # record fetches it once.
          def find_resource
            @find_resource ||= super
          end

          # Every action on an import is a bulk write of the products it
          # creates, and its rows expose the uploaded data — so reads are gated
          # by the write key too, exactly as on the operator's branch.
          def action_kind
            'write'
          end

          def build_resource
            klass = resolve_import_type(permitted_params[:type])

            # An unresolvable type must not fall back to the base class: that
            # would build an import the model's whitelist rejects with a
            # confusing error rather than saying the type is not a seller's to
            # run.
            klass ||= Spree::Import

            attrs = permitted_params.except(:type).merge(
              store: current_store,
              seller: current_seller,
              user: try_spree_current_user
            )
            # The import-done email links back to the panel — allowed origins
            # only.
            attrs[:results_url] = validated_results_url(attrs[:results_url])
            klass.new(attrs)
          end

          def permitted_params
            params.permit(*model_additional_permitted_attributes, :type, :attachment, :preferred_delimiter, :results_url)
          end

          # The registered Import subclass matching `name`, or nil.
          #
          # Takes the API shorthand (`"products"`) or the class name, like the
          # operator's twin, but selects from this branch's own allowlist
          # rather than the full registry.
          def resolve_import_type(name)
            return nil if name.blank?

            name = name.to_s
            permitted_import_types.find { |type| type.api_type == name || type.to_s == name }
          end

          # Intersected with the registry rather than constantized from the
          # list: a host app that unregisters an import type should not find it
          # still reachable here.
          def permitted_import_types
            Spree::Import.available_types.select { |type| PERMITTED_TYPES.include?(type.to_s) }
          end

          private

          # The caller-provided URL the done email links back to, honored only
          # when it matches one of the store's allowed origins.
          #
          # Stated here rather than shared with the operator's twin: that one
          # lives on the admin anchor, and the two branches are parallel by
          # design — inheriting across them is what this branch exists to avoid.
          # No configured origins means no caller URL is honored.
          #
          # @return [String, nil]
          def validated_results_url(url)
            return if url.blank?
            return unless current_store.allowed_origin?(url)

            url
          end

          def render_unknown_type
            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
              message: 'Unknown import type',
              status: :unprocessable_content
            )
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
