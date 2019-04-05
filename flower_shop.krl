ruleset flower_shop {
  meta {
    shares __testing, orders
    use module io.picolabs.subscription alias Subscription
  }
  global {
    __testing = { "queries":
      [ { "name": "__testing" }
      //, { "name": "entry", "args": [ "key" ] }
      ] , "events":
      [ //{ "domain": "d1", "type": "t1" }
      //, { "domain": "d2", "type": "t2", "attrs": [ "a1", "a2" ] }
      ]
    }
    orders = function() {
      ent:orderMap
    }
  }
  
  rule on_choose_bidder {
    select when order choose_bidder
  }
  
  rule on_gather_bid {
    select when bid process
    pre {
      orderSequenceNumber = event:attrs{"orderSequenceNumber"}
      driverEci = event:attrs{"driverEci"}
      bidAmount = event:attrs{"bidAmount"}
      estimatedDeliveryTime = event:attrs{"estimatedDeliveryTime"}
    }
    always {
      ent:orderMap{[orderSequenceNumber, "bids"]} := ent:orderMap{[orderSequenceNumber, "bids"]}.append({
        "driverEci": driverEci,
        "bidAmount": bidAmount,
        "estimatedDeliveryTime": estimatedDeliveryTime
      })
    }
  }
  
  rule on_new_order {
    select when order new
    pre {
      pickupTime = event:attrs{"pickupTime"}
      deliveryTime = event:attrs{"deliveryTime"}
    }
    always {
      order = { 
        "orderSequenceNumber": ent:orderSequenceNumber, 
        "selectedDriver": null,
        "deliveryStatus": "not delivered",
        "pickupTime": pickupTime, 
        "deliveryTime": deliveryTime,
        "location": "not implemented",
        "bids": []
      };
      ent:orderMap{ent:orderSequenceNumber} := order;
      ent:orderSequenceNumber := ent:orderSequenceNumber + 1;
      raise order event "broadcast"
        attributes order;
      schedule order event "choose_bidder" at time:add(time:now(), {"seconds": 60})
    }
  }
  
  rule on_order_broadcast {
    select when order broadcast
    foreach Subscription:established("Tx_role", "driver") setting (subscription)
      pre {
        eci = subscription{"Tx"}
        whoAmI = subscription{"Rx"}
        pickupTime = event:attrs{"pickupTime"}
        deliveryTime = event:attrs{"deliveryTime"}
        location = event:attrs{"location"}
        orderSequenceNumber = event:attrs{"orderSequenceNumber"}
      }
      event:send({
        "eci": eci,
        "edi": "eid",
        "domain": "bid",
        "type": "request",
        "attrs": {
          "who": whoAmI,
          "pickupTime": pickupTime,
          "deliveryTime": deliveryTime,
          "location": location,
          "orderSequenceNumber": orderSequenceNumber
        }
      })
  }
  
  rule auto_accept {
    select when wrangler inbound_pending_subscription_added
    pre {
      attributes = event:attrs.klog("subcription:")
    }
    always {
      raise wrangler event "pending_subscription_approval"
        attributes attributes
    }
  }
  
  rule on_installation {
    select when wrangler ruleset_added where rids >< meta:rid
    pre {
    }
    noop()
    fired{
      ent:orderSequenceNumber := 0;
      ent:orderMap := {};
    }
  }
}
