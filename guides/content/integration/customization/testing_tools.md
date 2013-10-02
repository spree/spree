---
title: Testing Tools
---

## Testing Tools

There are many ways to test Endpoints, in the next sections we will cover some of them.

***
For detailed information about Endpoints, check out the [endpoints](terminology#endpoints) section of the Terminology guide.
***

## Curl

In follow example we will use the [echo_endpoint](https://github.com/spree/echo_endpoint). It is a Sinatra Endpoint implemeted using the [endpoint_base](https://github.com/spree/endpoint_base).

To start the echo_enpoint you can run `rackup` as any other Sinatra application.

```bash
bundle exec ENDPOINT_KEY=MY-TOKEN rackup

[2013-10-01 14:20:56] INFO  WEBrick 1.3.1
[2013-10-01 14:20:56] INFO  ruby 2.0.0 (2013-06-27) [x86_64-darwin12.4.0]
[2013-10-01 14:20:56] INFO  WEBrick::HTTPServer#start: pid=44161 port=9292
```

Assuming you have your Endpoint running, you can easily test it by making a POST request with Curl.

```bash
$ curl -i -X POST -d '{"message":"echo:received","message_id":"xyz","payload":{}}' \
  -H "X-Augury-Token:MY-TOKEN" \
  -H "Content-Type:application/json" \
  http://localhost:9292/

HTTP/1.1 200 OK
Content-Type: application/json;charset=utf-8
Content-Length: 34
X-Content-Type-Options: nosniff
Server: WEBrick/1.3.1 (Ruby/2.0.0/2013-06-27)
Date: Tue, 29 Set 2013 22:00:00 ET
Connection: Keep-Alive

{"message_id":"xyz","received":{}}
```

In this example we used the service received available in the echo_endpoint, it always return the received message_id and HTTP 200 OK.

You will probably need to adjust the message content for your Endpoint requirements. In most cases the message content is bigger than in the previous example, in these cases you can pass the message content in a file.

```bash
curl -i -X POST -d @message.json -H "X-Augury-Token:MY-TOKEN" \
  -H "Content-Type:application/json" \
  http://localhost:9292/
```

---message.json---
```json
{
    "message": "amazon:import:by_number",
    "message_id": "xyz",
    "payload": {
        "amazon_order_id": "100-0000000-0000000",
        "parameters": [
          { "name": "amazon.marketplace_id",  "value": "nama9vach3kis" },
          { "name": "amazon.seller_id",       "value": "hugi0ty8su2zyh" },
          { "name": "amazon.aws_access_key",  "value": "Aqws3958dhdjwb39" },
          { "name": "amazon.secret_key",      "value": "dj20492dhjkdjeh2838w7" }
        ]
    }
}
```

Even though the previous examples look simple, sometimes these requests can become complex and hard to debug. The [RequestBin](http://requestb.in/) is a very useful and free tool to check the request information. You can create a RequestBin, POST to its url then check if all mandatory headers are included i.e. "X-Augury-Token", if it is using HTTP POST and the request content itself.

```bash
curl -i -X POST -d @message.json -H "X-Augury-Token:MY-TOKEN" \
  -H "Content-Type:application/json" \
  http://requestb.in/REQUESTBIN-TOKEN
```

## Ruby Scripts

When you are creating a new Endpoint you will probably test it several times and with variety of data. Creating a simple Ruby script to test the Endpoint can be very handy specially to debug the input and output from external resources as follows:

```ruby
require 'httparty'
require 'json'
require 'multi_json'

ACCESS      = ENV['ACCESS']
SECRET      = ENV['SECRET']
MARKETPLACE = ENV['MARKETPLACE']
SELLER      = ENV['SELLER']

request = { message: 'amazon:import:by_number',
            message_id: 'some_id',
            payload:
            { amazon_order_id: ARGV[0],
              parameters: [
                { name: "amazon.marketplace_id",  value: MARKETPLACE },
                { name: "amazon.seller_id",       value: SELLER },
                { name: 'amazon.aws_access_key',  value: ACCESS },
                { name: 'amazon.secret_key',      value: SECRET }
            ] } }

puts 'Request:'
puts JSON.pretty_generate(request)

result = HTTParty.post('http://localhost:9292/get_order_by_number',
                       body: request.to_json,
                       format: :json)

puts 'Response:'
puts JSON.pretty_generate(result)
```
We used the script above in the development of the service get_order_by_number available in the [Amazon Endpoint](https://github.com/spree/amazon_endpoint/).

## Spree Hub Connector Testing Tool

All Testing methods detailed before try to reproduce the requests made by the Spree Hub to your Endpoint.

In order to use the Testing Tool you have to configure you Endpoint properly in Spree Hub Connector/Add New Integration.

The Testing Tool makes real tests, when you send a message through it, the message will be inserted in the Spree Hub Incoming Queue via [Hub API](/integration/push.html). The Spree Hub will process the message, move it to Accepted Queue then make a request to your Endpoint with all configured parameters.


