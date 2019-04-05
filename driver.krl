ruleset driver {
  meta {
    shares __testing
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
  }
  rule on_bid_request {
    select when bid request
    pre {
      pickupTime = event:attrs{"pickupTime"}
      deliveryTime = event:attrs{"deliveryTime"}
    }
    if pickupTime != null && deliveryTime != null then noop()
    fired {
      raise bid event "process"
        attributes event:attrs;
    }
  }
  
  rule on_bid_process {
    select when bid process
    pre {
      pickupTime = event:attrs{"pickupTime"}.klog("process pickup time: ")
      deliveryTime = event:attrs{"deliveryTime"}.klog("process delivery time: ")
    }
  }
  
  rule on_make_bid {
    select when bid make_bid
    pre {
      flowerShopEci = event:attrs{"flowerShopEci"}
      pickupTime = event:attrs{"pickupTime"}
      deliveryTime = event:attrs{"deliveryTime"}
      location = event:attrs{"location"}
      orderSequenceNumber = event:attrs{"orderSequenceNumber"}
    }
    event:send({
      "eci": flowerShopEci,
      "eid": "none",
      "domain": "bid",
      "type": "process",
      "attrs": {
        "driverEci": meta:eci,
        "bidAmount": 30,
        "estimatedDeliveryTime": 10,
        "orderSequenceNumber": orderSequenceNumber
      }
    })
  }
  
}
