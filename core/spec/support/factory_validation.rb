require 'ice_nine'

# @api private
module FactoryValidation
  EXCLUDED_FACTORIES = IceNine.deep_freeze(%i[
    customer_return_without_return_items
    stock_packer
    stock_package
    stock_package_fulfilled
  ].to_set)

  TRANSACTION_OPTIONS = IceNine.deep_freeze(isolation: :serializable)

  private_constant(*constants(false))

  # Validate factories
  #
  # @return [self]
  #
  # @raise [Exception]
  #   on failed validation
  #
  def self.call
    (factory_names - EXCLUDED_FACTORIES).each(&method(:lint))

    self
  end

  # The factory names
  #
  # @return [Set<Symbol>]
  def self.factory_names
    FactoryGirl.factories.map(&:name).to_set
  end
  private_class_method :factory_names

  # Perform validation of factory
  #
  # @param factory_name [Symbol]
  #
  # @return [undefined]
  #
  # @raise [Exception]
  #   on failed validation
  #
  def self.lint(factory_name)
    ActiveRecord::Base.transaction(TRANSACTION_OPTIONS) do |transaction|
      FactoryGirl.create(factory_name)
      fail ActiveRecord::Rollback
    end
  end
  private_class_method :lint
end # FactoryValidation
