module Spree
  module Admin
    class RecordList
      class FilterGroup
        COMBINATORS = %i[and or].freeze

        attr_accessor :combinator, :filters, :groups, :id

        def initialize(combinator: :and, filters: [], groups: [], id: nil)
          @combinator = combinator.to_sym
          @filters = filters
          @groups = groups
          @id = id || SecureRandom.hex(8)
        end

        # Add a filter to this group
        # @param filter [Filter]
        def add_filter(filter)
          @filters << filter
        end

        # Add a nested group
        # @param group [FilterGroup]
        def add_group(group)
          @groups << group
        end

        # Remove a filter by id
        # @param filter_id [String]
        def remove_filter(filter_id)
          @filters.reject! { |f| f.id == filter_id }
        end

        # Remove a nested group by id
        # @param group_id [String]
        def remove_group(group_id)
          @groups.reject! { |g| g.id == group_id }
        end

        # Check if group is empty
        # @return [Boolean]
        def empty?
          @filters.empty? && @groups.empty?
        end

        # Convert to ransack params format
        # AND groups use regular params: { name_cont: 'value', status_eq: 'active' }
        # OR groups use ransack groupings: { g: { '0' => { m: 'or', c: { ... } } } }
        # @return [Hash]
        def to_ransack_params
          if combinator == :or
            to_or_ransack_params
          else
            to_and_ransack_params
          end
        end

        # Convert to hash for JSON serialization
        # @return [Hash]
        def to_h
          {
            combinator: combinator,
            filters: filters.map(&:to_h),
            groups: groups.map(&:to_h),
            id: id
          }
        end

        # Create from params hash
        # @param params [Hash]
        # @return [FilterGroup]
        def self.from_params(params)
          return new if params.blank?

          params = params.symbolize_keys if params.respond_to?(:symbolize_keys)

          group = new(
            combinator: params[:combinator] || :and,
            id: params[:id]
          )

          Array(params[:filters]).each do |filter_params|
            filter = Filter.from_params(filter_params)
            group.add_filter(filter) if filter
          end

          Array(params[:groups]).each do |group_params|
            nested_group = from_params(group_params)
            group.add_group(nested_group) if nested_group
          end

          group
        end

        private

        def to_and_ransack_params
          result = {}

          filters.each do |filter|
            result.merge!(filter.to_ransack_param)
          end

          groups.each_with_index do |group, index|
            if group.combinator == :or
              result[:g] ||= {}
              result[:g][index.to_s] = build_or_grouping(group)
            else
              result.merge!(group.to_ransack_params)
            end
          end

          result
        end

        def to_or_ransack_params
          {
            g: {
              '0' => build_or_grouping(self)
            }
          }
        end

        def build_or_grouping(group)
          conditions = {}

          group.filters.each_with_index do |filter, index|
            param = filter.to_ransack_param
            next if param.empty?

            conditions[index.to_s] = {
              a: { '0' => { name: filter.field, p: filter.operator.to_s.sub('_', ''), v: { '0' => { value: filter.value } } } }
            }
          end

          {
            m: 'or',
            c: conditions
          }
        end
      end
    end
  end
end
