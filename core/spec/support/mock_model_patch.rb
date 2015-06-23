require_dependency 'rspec/active_model/mocks/mocks'

module RspecMocksPatch
  extend ActiveSupport::Concern

  included { alias_method :_read_attribute, :[] }
end

RSpec::ActiveModel::Mocks::Mocks::ActiveRecordInstanceMethods.include(RspecMocksPatch)
