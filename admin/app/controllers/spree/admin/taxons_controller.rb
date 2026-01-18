module Spree
  module Admin
    class TaxonsController < ResourceController
      belongs_to 'spree/taxonomy'

      include Spree::Admin::TaxonsHelper
      include Spree::Admin::TagsHelper

      before_action :set_parent_permalink, only: :new
      before_action :set_permalink_part, only: [:edit, :update]
      before_action :set_permalink_params, only: [:update]

      update.before :set_parent
      update.before :set_position

      before_action :load_form_data, only: [:new, :create, :edit, :update]

      add_breadcrumb Spree.t(:products), :admin_products_path
      add_breadcrumb Spree.t(:taxonomies), :admin_taxonomies_path

      add_breadcrumb_icon 'package'
      before_action :add_breadcrumb_taxonomy

      def show
        redirect_to location_after_save
      end

      def select_options
        render json: taxons_options_json_array(with_automatic: params[:with_automatic].to_b)
      end

      def reposition
        authorize! :update, @taxon

        new_parent = @taxonomy.taxons.find(params.dig(:taxon, :new_parent_id))
        new_index = params.dig(:taxon, :new_position_idx).to_i

        if @taxon.move_to_child_with_index(new_parent, new_index)
          head :ok
        else
          head :unprocessable_entity
        end
      end

      private

      def parent_data
        super unless action == :select_options
      end

      def location_after_save
        spree.edit_admin_taxonomy_taxon_path(@taxon.taxonomy_id, @taxon.id)
      end

      def update_turbo_stream_enabled?
        true
      end

      def destroy_turbo_stream_enabled?
        true && !params[:force_redirect].to_b
      end

      def set_parent_permalink
        @parent_permalink = @taxon.parent.present? ? @taxon.parent.permalink : @taxon.taxonomy.root.permalink
      end

      def set_permalink_part
        @permalink_part = @taxon.permalink.split('/').last
        @parent_permalink = @taxon.permalink.split('/')[0...-1].join('/')
      end

      def set_position
        new_position = params[:taxon][:position]
        @taxon.child_index = new_position.to_i if new_position
      end

      def set_parent
        return unless params.dig(:taxon, :parent_id).present?

        @taxon.parent = @taxonomy.taxons.find_by(id: params.dig(:taxon, :parent_id))
      end

      def set_permalink_params
        return unless params[:permalink_part]

        params[:taxon] ||= {}
        params[:taxon][:permalink] = [@parent_permalink.presence, params[:permalink_part]].compact_blank.join('/')
      end

      def collection_url
        spree.admin_taxonomy_path(@taxonomy)
      end

      # this is needed to set the parent_id for the newly initialized taxons
      def build_resource
        parent.send(controller_name).build(parent_id: params.dig(:taxon, :parent_id))
      end

      def load_form_data
        @taxon_rules = Spree.taxon_rules
        @rule_types = @taxon_rules.map do |taxon_rule|
          [Spree.t("admin.taxon_rules.#{taxon_rule.to_s.demodulize.underscore}"), taxon_rule.to_s]
        end

        @rule_match_policies = Spree::TaxonRule::MATCH_POLICIES.map do |policy|
          [Spree.t("admin.taxon_rules.match_policies.#{policy}"), policy]
        end
      end

      def add_breadcrumb_taxonomy
        return unless @taxonomy.present?

        add_breadcrumb @taxonomy.name, collection_url

        if @object.present? && @object.persisted?
          add_breadcrumb @object.name, spree.edit_admin_taxonomy_taxon_path(@taxonomy, @object.id)
        end
      end

      def permitted_resource_params
        params.require(:taxon).permit(permitted_taxon_attributes)
      end
    end
  end
end
