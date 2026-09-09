# frozen_string_literal: true

module Spree
  # Shared list-position ordering for models using acts_as_list.
  #
  # Position is the merchant-facing precedence; id breaks ties so two rows
  # sharing a position resolve the same way on every read.
  module HasListPosition
    extend ActiveSupport::Concern

    included do
      scope :ordered, -> { order(Arel.sql("#{table_name}.position ASC, #{table_name}.id ASC")) }
    end
  end
end
