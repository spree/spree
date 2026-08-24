module Spree
  module Api
    module V3
      module Admin
        # The media library: every file in the store, whether or not it has been
        # placed on a product yet.
        #
        # Subclasses the product-scoped media controller for its create
        # branches, but drops the parent: a row created here has no viewable,
        # which is what makes uploading before deciding where a file goes
        # possible. Putting a file ON a product is the nested controller's job —
        # POST that product's media with this row's id as `source_media_id`.
        #
        # `source_media_id` works here too, and means "copy this file into the
        # library again" — an unplaced row sharing the original's blob.
        class MediaLibraryController < MediaController
          # Restates the base class's member actions with `usage` added — a
          # second `before_action :set_resource` would replace that filter
          # rather than extend it, leaving show/update/destroy without a record.
          before_action :set_resource, only: %i[show update destroy usage]

          # Deleting from the library means deleting the file. A file still in
          # use needs the caller to say so — `detach=true`, which the dashboard
          # sends after a confirmation showing the places — and then the file
          # is removed from all of them in one pass. Without it the delete is
          # refused with the usage list, so an API client can't take a file out
          # from under a catalog by accident. Removing a file from one
          # product's gallery is the nested endpoint's destroy, which stays
          # unguarded: that is removing a placement, not the file.
          def destroy
            references = Spree::MediaUsage.call(media: @resource).value
            return super if references.empty?

            unless detach_requested?
              return render_error(
                code: ERROR_CODES[:resource_invalid],
                message: Spree.t(
                  'api.errors.media_in_use',
                  places: references.filter_map(&:name).uniq.first(5).to_sentence
                ),
                status: :unprocessable_content,
                details: { usage: references.map { |reference| reference_payload(reference) } }
              )
            end

            result = Spree::MediaDeletion.call(media: @resource)
            return head :no_content if result.success?

            render_service_error(result.error)
          end

          # Where this file is in use — other products it has been placed on,
          # plain image fields sharing it, and descriptions embedding it. What
          # the dashboard shows before a merchant deletes something.
          def usage
            references = Spree::MediaUsage.call(media: @resource).value

            render json: { data: references.map { |reference| reference_payload(reference) } }
          end

          protected

          def detach_requested?
            ActiveModel::Type::Boolean.new.cast(params[:detach])
          end

          def reference_payload(reference)
            {
              kind: reference.kind,
              name: reference.name,
              owner_type: reference.owner_type,
              owner_id: reference.owner_id,
              field: reference.field
            }
          end

          # Reading where a file is used is reading the file, for the key gate
          # and for CanCanCan alike. The latter needs saying twice: `read_actions`
          # settles the required API-key scope, while this maps the action onto
          # an ability a role actually grants — CanCanCan's `:read` alias covers
          # only index and show, so a staffer with read access would otherwise
          # be refused.
          def read_actions
            super + %w[usage]
          end

          def authorize_resource!(resource = @resource, action = action_name.to_sym)
            super(resource, action == :usage ? :show : action)
          end

          # No parent to resolve. The library is the store's own collection, so
          # tenancy comes from the store_id on the rows themselves rather than
          # from a product two hops away.
          def set_parent
            @parent = nil
          end

          # The listing shows one row per file; member actions resolve any row.
          #
          # Reuse shares a blob across rows, so a picture placed on three
          # products is three rows of the same image — the library shows files,
          # and `usage` says where each one appears. But a row the grouping
          # hides is still a real record a client may hold the id of, so
          # narrowing every lookup would 404 it on show or destroy.
          def scope
            media = current_store.media.order(created_at: :desc)
            listing? ? media.distinct_by_file : media
          end

          def listing?
            action_name == 'index'
          end

          # A library row is born unplaced. `viewable` stays nil until someone
          # copies the file onto a product.
          def build_resource
            current_store.media.build(media_attributes)
          end

          # There is no product to fetch into, so the URL import job — which
          # takes a viewable — has nothing to target. A merchant importing by
          # URL does it from the product they are filling.
          def create_from_url
            render_error(
              code: Spree::Api::V3::ErrorHandler::ERROR_CODES[:resource_invalid],
              message: Spree.t('api.errors.media_url_import_requires_product'),
              status: :unprocessable_content
            )
          end
        end
      end
    end
  end
end
