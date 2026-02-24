# frozen_string_literal: true

module Spree
  module Api
    module V3
      class PostCategorySerializer < BaseSerializer
        typelize title: :string, slug: :string

        attributes :title, :slug, created_at: :iso8601, updated_at: :iso8601
      end
    end
  end
end
