module Spree
  module Api
    module V3
      module Seller
        # A seller's own CSV exports.
        #
        # The operator's counterpart offers whatever the registry holds; this
        # branch offers only the datasets that can be narrowed to one seller,
        # because tenancy here is the narrowing. `Spree::Export#scope` refuses
        # a model without `for_seller` rather than writing a file spanning the
        # marketplace, and ALLOWED_TYPES is the front door onto the same rule —
        # a type added to the registry is not reachable from a seller's panel
        # until someone has decided it can be scoped.
        #
        # No index: a seller creates an export, polls it and downloads it, so
        # there is no history page to list. No destroy either — retention is
        # the marketplace's business.
        class ExportsController < Seller::ResourceController
          include ActiveStorage::SetCurrent

          # Exports of records a seller genuinely owns. Both narrow by their own
          # `seller_id`, which is the same answer `current_seller.orders` and
          # `current_seller.products` give the list endpoints.
          ALLOWED_TYPES = %w[orders products].freeze

          scoped_resource :exports

          # POST /api/v3/seller/exports
          #
          # Refused before the record is built when the type is not one a
          # seller may run — `build_resource` would otherwise have no class to
          # instantiate.
          def create
            return render_unsupported_type if resolve_export_type(params[:type]).nil?

            super
          end

          # GET /api/v3/seller/exports/:id/download
          #
          # Streamed inline rather than redirected to ActiveStorage's signed
          # URL: the panel is served under a path-based mount and proxies only
          # `/api/*`, so a cross-origin redirect would strip the Authorization
          # header and fail silently.
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
            Spree.api.seller_export_serializer
          end

          def scope_includes
            [{ attachment_attachment: :blob }]
          end

          # Rooted in the seller's own exports, so another seller's id reads as
          # missing rather than denied — the same shape every endpoint on this
          # branch has.
          def seller_association
            :exports
          end

          # Loaded by both the scope gate and the member actions — memoize so
          # the record is fetched once.
          def find_resource
            @find_resource ||= super
          end

          # An export is a bulk read of the records it contains, so creating
          # and downloading one both check the read-level key.
          def action_kind
            'read'
          end

          def read_actions
            %w[show create download]
          end

          # Gated by the scope of what is being exported, not by an "exports"
          # scope of its own: an orders export needs `read_orders`.
          def scoped_resource_name
            export_class&.required_scope || :all
          end

          # Authorized against the records being exported rather than the
          # export row.
          #
          # An export is a bulk read of its contents, so "may this seller read
          # orders" is the real question — and it is the same one
          # `scoped_resource_name` asks the key gate. `Spree::Export` is not a
          # catalog subject in its own right, so authorizing the row itself
          # would deny every principal that is not a full-access admin.
          def authorize_resource!(resource = @resource, _action = action_name.to_sym)
            model = resource.is_a?(Spree::Export) ? resource.model_class : resource

            authorize!(:show, model)
          end

          # The seller and the store both come from the session rather than the
          # payload — a seller cannot file an export against anyone else.
          def build_resource
            klass = resolve_export_type(permitted_params[:type])

            klass.new(
              permitted_params.except(:type).merge(
                store: current_store,
                seller: current_seller,
                user: try_spree_current_user,
                results_url: validated_results_url(permitted_params[:results_url])
              )
            )
          end

          # `search_params` carries an arbitrary Ransack hash with nested
          # groupings, which Rails' `permit(k: {})` rejects — extract via
          # `to_unsafe_h`. `:format` is deliberately dropped: only CSV exists,
          # and Rails' request format would otherwise overwrite the enum.
          def permitted_params
            attrs = params.permit(*model_additional_permitted_attributes, :type, :record_selection, :results_url)
            raw = params[:search_params]
            attrs[:search_params] = raw.respond_to?(:to_unsafe_h) ? raw.to_unsafe_h : raw if raw.present?
            attrs
          end

          # Resolves the API shorthand (`"orders"`) against the allowlist.
          #
          # The class comes from the in-process registry, never from the
          # request — the parameter only selects an entry, so no user input is
          # ever constantized.
          def resolve_export_type(name)
            return nil if name.blank?

            name = name.to_s
            return nil unless ALLOWED_TYPES.include?(name)

            Spree::Export.available_types.find { |type| type.api_type == name || type.to_s == name }
          end

          private

          def export_class
            action_name == 'create' ? resolve_export_type(params[:type]) : find_resource.class
          end

          # Where the done email sends the seller back to. The panel passes its
          # own location, since only it knows where it is mounted — this
          # branch is served from a path under the store as often as from a
          # host of its own — and the store's allowed origins decide whether to
          # trust it.
          def validated_results_url(url)
            return if url.blank?
            return unless current_store.allowed_origin?(url)

            url
          end

          def render_unsupported_type
            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:validation_error],
              message: Spree.t(
                'api.errors.unsupported_export_type',
                default: "Unsupported export type. Supported types: #{ALLOWED_TYPES.join(', ')}"
              ),
              status: :unprocessable_content
            )
          end
        end
      end
    end
  end
end
