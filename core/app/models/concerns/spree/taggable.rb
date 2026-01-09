module Spree
  module Taggable
    extend ActiveSupport::Concern

    class_methods do
      # Macro to define tagging on specific contexts
      # Example: spree_taggable_on :tags, :labels
      def spree_taggable_on(*tag_types)
        tag_types = tag_types.to_a.flatten.compact.map(&:to_sym)

        class_attribute :tag_types unless respond_to?(:tag_types)
        self.tag_types ||= []
        self.tag_types = (self.tag_types + tag_types).uniq

        class_attribute :taggable_tenant_column unless respond_to?(:taggable_tenant_column)
        self.taggable_tenant_column = nil

        # Include instance methods
        include Spree::Taggable::InstanceMethods

        # Add general taggings association (all contexts)
        unless reflect_on_association(:taggings)
          has_many :taggings,
                   as: :taggable,
                   class_name: 'Spree::Tagging',
                   dependent: :destroy
        end

        # Setup associations and methods for each tag type
        tag_types.each do |tag_type|
          setup_taggable(tag_type)
        end

        # Setup tagged_with scope
        setup_tagged_with_scope
      end

      # Macro to set tenant column for multi-tenancy support
      # Example: spree_taggable_tenant :store_id
      def spree_taggable_tenant(tenant_column)
        self.taggable_tenant_column = tenant_column.to_sym
      end

      # @deprecated Use {#spree_taggable_on} instead. This method will be removed in Spree 5.5.
      def acts_as_taggable_on(*tag_types)
        Spree::Deprecation.warn(
          'acts_as_taggable_on is deprecated and will be removed in Spree 5.5. ' \
          'Please use spree_taggable_on instead.',
          caller
        )
        spree_taggable_on(*tag_types)
      end

      # @deprecated Use {#spree_taggable_tenant} instead. This method will be removed in Spree 5.5.
      def acts_as_taggable_tenant(tenant_column)
        Spree::Deprecation.warn(
          'acts_as_taggable_tenant is deprecated and will be removed in Spree 5.5. ' \
          'Please use spree_taggable_tenant instead.',
          caller
        )
        spree_taggable_tenant(tenant_column)
      end

      private

      def setup_taggable(tag_type)
        context = tag_type.to_s

        # Define has_many association for taggings
        has_many :"#{tag_type.to_s.singularize}_taggings",
                 -> { where(context: context) },
                 as: :taggable,
                 class_name: 'Spree::Tagging',
                 dependent: :destroy

        # Define has_many association for tags through taggings
        has_many tag_type,
                 through: :"#{tag_type.to_s.singularize}_taggings",
                 source: :tag,
                 class_name: 'Spree::Tag'

        # Define getter for tag_list (e.g., tag_list, label_list)
        define_method :"#{tag_type.to_s.singularize}_list" do
          tag_list_on(context)
        end

        # Define setter for tag_list (e.g., tag_list=, label_list=)
        define_method :"#{tag_type.to_s.singularize}_list=" do |new_tags|
          set_tag_list_on(context, new_tags)
        end

        # Define _previously_changed? method for dirty tracking
        define_method :"#{tag_type.to_s.singularize}_list_previously_changed?" do
          instance_variable_get(:"@#{tag_type.to_s.singularize}_list_changed") || false
        end
      end

      def setup_tagged_with_scope
        # Skip if already defined
        return if respond_to?(:tagged_with) && method(:tagged_with).owner == singleton_class

        # Define scope for finding records tagged with specific tags
        scope :tagged_with, ->(tag_names, options = {}) {
          return none if tag_names.blank?

          tag_names = parse_tag_names(tag_names)
          return none if tag_names.empty?

          context = options[:on] || 'tags'
          any = options[:any]
          exclude = options[:exclude]

          if exclude
            tagged_with_exclude(tag_names, context: context, any: any)
          elsif any
            tagged_with_any(tag_names, context: context)
          else
            tagged_with_all(tag_names, context: context)
          end
        }

        # Helper to parse tag names from various input formats
        define_singleton_method :parse_tag_names do |tag_names|
          case tag_names
          when Array
            tag_names.flatten.compact.map(&:to_s).map(&:strip).reject(&:blank?)
          when String
            tag_names.split(',').map(&:strip).reject(&:blank?)
          else
            [tag_names.to_s.strip].reject(&:blank?)
          end
        end

        # Scope to find records tagged with ANY of the given tags
        define_singleton_method :tagged_with_any do |tag_names, context:|
          tag_ids = Spree::Tag.named_any(tag_names).pluck(:id)
          return none if tag_ids.empty?

          # Use unique alias to support chaining multiple tagged_with calls
          tagging_alias = "tagging_#{context}_#{tag_ids.hash.abs}"
          tagging_table = connection.quote_table_name(Spree::Tagging.table_name)
          tagging_alias_quoted = connection.quote_table_name(tagging_alias)
          model_table = connection.quote_table_name(table_name)
          model_pk = connection.quote_column_name(primary_key)
          model_name = connection.quote(name)
          context_quoted = connection.quote(context)

          # Put all conditions in JOIN to avoid WHERE conflicts when chaining
          joins("INNER JOIN #{tagging_table} #{tagging_alias_quoted} ON #{tagging_alias_quoted}.taggable_id = #{model_table}.#{model_pk} AND #{tagging_alias_quoted}.taggable_type = #{model_name} AND #{tagging_alias_quoted}.context = #{context_quoted} AND #{tagging_alias_quoted}.tag_id IN (#{tag_ids.join(',')})")
            .distinct
        end

        # Scope to find records tagged with ALL of the given tags
        define_singleton_method :tagged_with_all do |tag_names, context:|
          tag_ids = Spree::Tag.named_any(tag_names).pluck(:id)
          return none if tag_ids.empty? || tag_ids.size < tag_names.size

          # Use unique alias to support chaining multiple tagged_with calls
          tagging_alias = "tagging_#{context}_#{tag_ids.hash.abs}"
          tagging_table = connection.quote_table_name(Spree::Tagging.table_name)
          tagging_alias_quoted = connection.quote_table_name(tagging_alias)
          model_table = connection.quote_table_name(table_name)
          model_pk = connection.quote_column_name(primary_key)
          model_name = connection.quote(name)
          context_quoted = connection.quote(context)

          if tag_names.size == 1
            # Single tag: simple join with all conditions in ON clause
            joins("INNER JOIN #{tagging_table} #{tagging_alias_quoted} ON #{tagging_alias_quoted}.taggable_id = #{model_table}.#{model_pk} AND #{tagging_alias_quoted}.taggable_type = #{model_name} AND #{tagging_alias_quoted}.context = #{context_quoted} AND #{tagging_alias_quoted}.tag_id = #{tag_ids.first}")
              .distinct
          else
            # Multiple tags: need subquery to find records with ALL tags
            subquery = Spree::Tagging
              .select(:taggable_id)
              .where(taggable_type: name, context: context, tag_id: tag_ids)
              .group(:taggable_id)
              .having("COUNT(DISTINCT tag_id) = ?", tag_names.size)

            where(id: subquery)
          end
        end

        # Scope to exclude records tagged with given tags
        define_singleton_method :tagged_with_exclude do |tag_names, context:, any:|
          tag_ids = Spree::Tag.named_any(tag_names).pluck(:id)
          return all if tag_ids.empty?

          subquery = Spree::Tagging
            .select(:taggable_id)
            .where(taggable_type: name, context: context, tag_id: tag_ids)

          if any
            # Exclude records that have ANY of the tags
            where.not(id: subquery)
          else
            # Exclude records that have ALL of the tags
            having_all = Spree::Tagging
              .select(:taggable_id)
              .where(taggable_type: name, context: context, tag_id: tag_ids)
              .group(:taggable_id)
              .having("COUNT(DISTINCT tag_id) = ?", tag_names.size)

            where.not(id: having_all)
          end
        end
      end
    end

    module InstanceMethods
      # Get tag list for a specific context
      # @param context [String, Symbol] the tagging context (e.g., :tags, :labels)
      # @return [Spree::TagList] the list of tags
      def tag_list_on(context)
        context = context.to_s
        cache_var = "@#{context.singularize}_list_cache"

        return instance_variable_get(cache_var) if instance_variable_defined?(cache_var)

        tags = taggings_for_context(context).includes(:tag).map { |t| t.tag.name }
        list = Spree::TagList.new(tags)
        list.taggable = self
        list.context = context
        instance_variable_set(cache_var, list)
      end

      # Set tag list for a specific context
      # @param context [String, Symbol] the tagging context (e.g., :tags, :labels)
      # @param new_tags [Array, String, Spree::TagList] the new tags
      def set_tag_list_on(context, new_tags)
        context = context.to_s
        cache_var = "@#{context.singularize}_list_cache"
        changed_var = "@#{context.singularize}_list_changed"

        new_list = Spree::TagList.new(parse_tag_list(new_tags))
        new_list.taggable = self
        new_list.context = context
        old_list = tag_list_on(context)

        instance_variable_set(cache_var, new_list)
        instance_variable_set(changed_var, old_list.sort != new_list.sort)

        # Schedule tag list to be saved after commit
        @tag_list_changes ||= {}
        @tag_list_changes[context] = new_list.to_a
      end

      # Get all tags for a context (class method style via instance)
      def all_tags_on(context)
        taggings_for_context(context).includes(:tag).map(&:tag)
      end

      # Save tags after the record is saved
      def save_tags
        return unless @tag_list_changes.present?

        @tag_list_changes.each do |context, new_tags|
          save_tags_for_context(context, new_tags)
        end

        @tag_list_changes = {}
      end

      private

      def taggings_for_context(context)
        Spree::Tagging.where(
          taggable_type: self.class.name,
          taggable_id: id,
          context: context.to_s
        )
      end

      def parse_tag_list(tags)
        case tags
        when Array
          tags.flatten.compact.map(&:to_s).map(&:strip).reject(&:blank?)
        when String
          tags.split(',').map(&:strip).reject(&:blank?)
        when nil
          []
        else
          [tags.to_s.strip].reject(&:blank?)
        end
      end

      def save_tags_for_context(context, new_tags)
        return unless persisted?

        current_taggings = taggings_for_context(context).includes(:tag)
        current_tag_names = current_taggings.map { |t| t.tag.name.downcase }
        new_tag_names = new_tags.map(&:downcase)

        # Tags to remove
        tags_to_remove = current_taggings.select { |t| !new_tag_names.include?(t.tag.name.downcase) }
        tags_to_remove.each(&:destroy)

        # Tags to add
        names_to_add = new_tags.select { |name| !current_tag_names.include?(name.downcase) }

        tenant_value = if self.class.taggable_tenant_column && respond_to?(self.class.taggable_tenant_column)
                         send(self.class.taggable_tenant_column)&.to_s
                       end

        names_to_add.each do |name|
          tag = Spree::Tag.find_or_create_with_like_by_name(name)
          Spree::Tagging.create!(
            tag: tag,
            taggable: self,
            context: context,
            tenant: tenant_value
          )
        end

        # Clear cache
        cache_var = "@#{context.singularize}_list_cache"
        remove_instance_variable(cache_var) if instance_variable_defined?(cache_var)
      end
    end

    included do
      after_save :save_tags
    end
  end
end
