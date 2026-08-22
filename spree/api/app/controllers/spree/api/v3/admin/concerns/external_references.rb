module Spree
  module Api
    module V3
      module Admin
        module Concerns
          # Lets a connector address records by the identity its own system
          # knows, rather than by Spree's prefixed id.
          #
          # Two halves:
          #
          # * **write** — `external_references` in the payload records the
          #   caller's key for the record it just wrote. Systems the payload
          #   does not mention keep their references, so a PIM sync never
          #   erases the ERP's key.
          # * **read** — a member path may carry `external:<system>:<id>` in
          #   place of the prefixed id, so a connector that only ever learned
          #   the ERP's key can read, update and delete without first asking
          #   Spree for its id.
          #
          # A create carrying an `external_references` entry that already
          # matches a record **updates that record** instead of failing on the
          # unique index — the upsert a nightly feed needs, since a feed cannot
          # know whether Spree has seen a row before.
          #
          # The write hangs off +serialize_resource+ rather than overriding
          # +create+/+update+: several admin controllers implement those
          # themselves (products and orders route through workflows), and every
          # one of them reaches serialization with the saved record. Rendering
          # is the one place they all agree on.
          module ExternalReferences
            extend ActiveSupport::Concern

            included do
              before_action :update_instead_when_external_id_known, only: :create
            end

            protected

            # A create whose payload names an external id Spree already knows
            # becomes an update of that record. Without this a re-run of the
            # same feed 422s on the unique index — after persisting a duplicate
            # on controllers whose +create+ builds through a workflow rather
            # than +build_resource+ — which reads to a connector author as "the
            # sync is broken" rather than "already imported".
            #
            # A before_action rather than a +build_resource+ override because
            # products and orders create through workflows and never call
            # +build_resource+; rendering from here halts the action, so every
            # controller's +create+ gets the same upsert.
            #
            # Dispatches into the controller's own +update+, which is the only
            # action that knows how to write that resource (orders update
            # through a service, products through a workflow).
            #
            # A controller whose two actions permit different keys would
            # silently drop a payload key the update action does not name.
            # +normalize_upsert_params!+ is where such a controller reconciles
            # them, and where one prepares state its update path expects; the
            # default is a no-op.
            def update_instead_when_external_id_known
              existing = find_by_external_reference_params
              return if existing.blank?

              @resource = existing
              authorize_resource!(@resource, :update)
              normalize_upsert_params!
              update
            end

            # Rewrites create-shaped keys into the ones this controller's
            # +update+ accepts. A no-op unless the two actions disagree.
            def normalize_upsert_params!; end

            # `external_references` lives in its own table, so it must not
            # reach the model's attribute writer.
            def permitted_params
              super.except(:external_references)
            end

            # Accepts both the `{ system => external_id }` map the serializer
            # renders — so a client can send back exactly what it read — and
            # the `[{ system:, external_id: }]` list a feed finds natural.
            def external_reference_params
              return @external_reference_params if defined?(@external_reference_params)

              raw = params[:external_references]
              return @external_reference_params = [] if raw.blank?

              raw = raw.to_unsafe_h if raw.respond_to?(:to_unsafe_h)
              entries =
                if raw.is_a?(Hash) && !raw.key?(:system) && !raw.key?('system')
                  raw.map { |system, external_id| { system: system, external_id: external_id } }
                else
                  Array(raw).map { |entry| entry.respond_to?(:to_unsafe_h) ? entry.to_unsafe_h : entry.to_h }
                end

              @external_reference_params = entries.filter_map do |entry|
                entry = entry.to_h.symbolize_keys.slice(:system, :external_id)
                next if entry[:system].blank?

                entry
              end
            end

            # A member path may address the record by an external identity
            # instead of its prefixed id, written `external:<system>:<id>` —
            # e.g. `/admin/products/external:erp:MAT-100`. A connector that
            # only ever learned the ERP's key can then read, update and delete
            # without first querying Spree for its id.
            #
            # It resolves through the controller's own +scope+, so store
            # scoping and authorization are exactly as they are for a prefixed
            # id, and a key belonging to another store is a 404.
            EXTERNAL_ID_PREFIX = 'external:'.freeze

            def find_resource
              return super unless external_id_lookup?

              _prefix, system, external_id = params[:id].split(':', 3)
              scope.find_by_external_id!(system, external_id)
            end

            def external_id_lookup?
              params[:id].to_s.start_with?(EXTERNAL_ID_PREFIX) &&
                model_class.respond_to?(:find_by_external_id) &&
                params[:id].to_s.split(':', 3).length == 3
            end

            def find_by_external_reference_params
              return if external_reference_params.blank?
              return unless model_class.respond_to?(:find_by_external_id)

              external_reference_params.each do |entry|
                match = scope.find_by_external_id(entry[:system], entry[:external_id])
                return match if match.present?
              end

              nil
            end

            def serialize_resource(resource, **options)
              write_external_references(resource)
              super
            end

            def write_external_references(resource)
              # Cheapest guard first: a GET must not even parse the params.
              return unless request.post? || request.patch? || request.put?
              return if external_reference_params.blank?
              return unless resource.respond_to?(:assign_external_references)
              return unless resource.persisted?

              resource.assign_external_references(external_reference_params)
              resource.external_references.reload
            end
          end
        end
      end
    end
  end
end
