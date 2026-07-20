module Spree
  # An evaluated onboarding task — the serializable result of running a
  # {Spree::SetupTasks} registry entry against its subject (e.g. a store).
  # See {Spree::Store#setup_tasks}.
  class SetupTask
    include ActiveModel::Model
    include ActiveModel::Attributes

    attribute :name, :string
    attribute :done, :boolean
  end
end
