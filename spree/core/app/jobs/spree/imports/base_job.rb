module Spree
  module Imports
    # Shared base for every job in the imports pipeline.
    #
    # The narrow transient-error retry policy is inherited from `Spree::BaseJob`;
    # we only override the queue here. Per-row business errors are caught inside
    # `Spree::ImportRow#process!` and converted to `row.fail!`, so they never
    # bubble up to the job layer. Subclasses may extend the retry list (e.g.
    # `CreateCategoriesJob` adds `RecordNotUnique` to recover from concurrent
    # taxon creation races).
    class BaseJob < Spree::BaseJob
      queue_as Spree.queues.imports
    end
  end
end
