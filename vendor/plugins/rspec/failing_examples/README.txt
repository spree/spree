"Why have failing examples?", you might ask.

They allow us to see failure messages. RSpec wants to provide meaningful and helpful failure messages. The failures in this directory not only provide you a way of seeing the failure messages, but they provide RSpec's own specs a way of describing what they should look like and ensuring they stay correct.

To see the types of messages you can expect, stand in this directory and run:

../bin/spec ./*.rb