module Spree
  module Api
    module V3
      # API-side counterpart to `Spree::Admin::BulkOperationsConcern`. Provides
      # the shared tag bulk actions, the `bulk_collection` relation, and the
      # `after_bulk_tags_change` hook controllers override (e.g. to reindex
      # search + match automatic taxons). Shape mirrors the legacy concern so
      # the two stay easy to keep in sync.
      module BulkOperations
        extend ActiveSupport::Concern

        # POST /api/v3/admin/<resource>/bulk_add_tags
        # Body: { ids: [...], tags: ['summer', 'sale'] }
        def bulk_add_tags
          authorize! :update, model_class

          Spree::Tags::BulkAdd.call(tag_names: Array(params[:tags]), records: bulk_collection)
          after_bulk_tags_change

          render json: bulk_tags_response
        end

        # POST /api/v3/admin/<resource>/bulk_remove_tags
        # Body: { ids: [...], tags: ['summer', 'sale'] }
        def bulk_remove_tags
          authorize! :update, model_class

          Spree::Tags::BulkRemove.call(tag_names: Array(params[:tags]), records: bulk_collection)
          after_bulk_tags_change

          render json: bulk_tags_response
        end

        private

        # Hook for controllers to perform additional work after bulk tag
        # mutations — e.g. enqueueing search reindex jobs, re-matching
        # automatic taxons. Mirrors `Spree::Admin::BulkOperationsConcern`.
        def after_bulk_tags_change
        end

        # Slim ability-scoped relation targeted by the inbound `ids` param.
        # Cross-store IDs and IDs the current admin can't update are silently
        # dropped before any mutation runs. Mirrors the legacy concern's
        # `bulk_collection` — no eager loads, because bulk endpoints only need
        # `id` + `store_ids` per record.
        def bulk_collection
          @bulk_collection ||= begin
            product_ids = decode_ids(params[:ids])
            model_class.for_store(current_store).accessible_by(current_ability, :update)
              .where(id: product_ids)
          end
        end

        # Default shape for bulk tag responses; controllers override
        # `bulk_record_count_key` to give the count its resource-named JSON key
        # (e.g. `product_count`, `order_count`). Mirrors how the legacy admin
        # concern delegates response shaping to the host controller.
        def bulk_tags_response
          {
            bulk_record_count_key => bulk_collection.size,
            tag_count: Array(params[:tags]).size
          }
        end

        def bulk_record_count_key
          :record_count
        end

        # Maps inbound IDs (a mix of prefixed `prod_…` strings and raw IDs) to
        # raw IDs. Anything that isn't a valid prefixed ID is passed through
        # verbatim, so legacy clients sending raw IDs keep working. Prefix
        # decoding is pure — no DB lookup needed.
        def decode_ids(ids)
          Array(ids).map do |id|
            Spree::PrefixedId.prefixed_id?(id) ? Spree::PrefixedId.decode_prefixed_id(id) : id
          end
        end
      end
    end
  end
end
