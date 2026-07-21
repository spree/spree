FactoryBot.define do
  # STI base can't be persisted (type must be a registered subclass), so the
  # factory defaults to DefaultLocation. Channels seed all built-in kinds on
  # create and `type` is unique per channel, so the factory clears the seeded
  # list — specs get a pristine channel whose only rule is the one built here.
  # Position defaults to the end of the channel's list via the model callback.
  factory :order_routing_rule, class: Spree::OrderRouting::Rules::DefaultLocation do
    channel { association(:channel).tap { |c| c.order_routing_rules.delete_all } }
    store { channel.store }

    factory :preferred_location_routing_rule, class: Spree::OrderRouting::Rules::PreferredLocation
    factory :minimize_splits_routing_rule, class: Spree::OrderRouting::Rules::MinimizeSplits
  end
end
