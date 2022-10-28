require 'rails_event_store'

Rails.configuration.to_prepare do
  Rails.configuration.event_store = event_store = RailsEventStore::Client.new
  event_store.subscribe(
    Checkout::Subscribe::OrderNotifier.new,
    to: [
      ::Checkout::Event::AddToCart, ::Checkout::Event::CreateOrder, ::Checkout::Event::DestroyCart,
      ::Checkout::Event::EmptyCart, ::Checkout::Event::RemoveCartItem, ::Checkout::Event::UpdateCart,
      ::Checkout::Event::AdvanceOrder, ::Checkout::Event::CompleteOrder, ::Checkout::Event::NextOrderState,
      ::Checkout::Event::UpdateOrder, ::Checkout::Event::SelectShipping
    ]
  )

  event_store.subscribe(
    Customer::Subscribe::PdpObserver.new, to: [::Customer::Event::PdpVisit]
  )
end
