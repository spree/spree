---
  title: "Core | Models | Activators"
---

## Overview

Activators are used to subscribe to specific events within Spree. Activators
have the following attributes:

* `description`: Useful text to be displayed in a list of activators.
* `expires_at`: The time at which the activator is no longer active. Can be set
  to `nil` to indicate a never-ending activator.
* `starts_at`: The time at which the activator should be active from. Can be set
  to `nil` to indicate the activator has always been active.
* `name`: The short name of the activator. Used with description to explain what
  the activator does.
* `event_name`: The event to subscribe to.

The subscription to these events is done with this code from inside the Spree
Core gem, which uses Active Support's Notifications API:

    ActiveSupport::Notifications.subscribe(/^spree\./) do |*args|
      event_name, start_time, end_time, id, payload = args
      Activator.active.event_name_starts_with(event_name).each do |activator|
        payload[:event_name] = event_name
        activator.activate(payload)
      end
    end

***
For documentation about `ActiveSupport::Notifications`, please see [the Rails
API page](http://api.rubyonrails.org/classes/ActiveSupport/Notifications.html)
***

This code from the engine class subscribes to all Active Support notifications
within the Rails application which begin with `spree.`. These events are
typically caused by the use of `fire_event` within Spree's controllers, like so:

    fire_event('spree.checkout.update')

This method itself calls `ActiveSupport::Notifications.instrument` and passes
through the arguments from this method. While it would seem that `fire_event` is
simply just a shorter way of calling the method, it's also configured to pass
through a default payload. This payload contains a `:user` key, and an `:order` key,
containing information about the current user (`try_spree_current_user`) and the
current order (`current_order`) respectively.

The `fire_event` method can be used to pass additional payload information
through too:

    fire_event('spree.checkout.update', :extra => "information")

By calling `fire_event`, the notifications hook that is defined inside the
engine is triggered. The next bit of the code finds all the currently active
`Activator` (and subclass) objects that match the event name. In the above
example, all active `Activator` objects which are configured to use the
`spree.checkout.update` event will be activated.

When each Activator object is activated, the `activate` method receives the
payload from the `fire_event` method. Whatever the activator does with this is
up to that specific activator.

For an example of how Activators are used, please see the 
<%= link_to "Promotions", :promotions %> guide.
