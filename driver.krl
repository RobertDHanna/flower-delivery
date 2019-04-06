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
    locationToDistance = function() {
      random:integer(5) + 5
    }
    pickBidAmount = function() {
      random:integer(15) + 5
    }
  }
  rule on_bid_request {
    select when bid request
    pre {
      pickupTime = event:attrs{"pickupTime"}
      deliveryTime = event:attrs{"deliveryTime"}
    }
    if pickupTime != null && deliveryTime != null && ent:activeDelivery == null then noop()
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
    if ent:activeDelivery == null then
      event:send({
        "eci": flowerShopEci,
        "eid": "none",
        "domain": "bid",
        "type": "process",
        "attrs": {
          "driverEci": meta:eci,
          "bidAmount": pickBidAmount(),
          "estimatedDeliveryTime": locationToDistance(),
          "orderSequenceNumber": orderSequenceNumber
        }
      })
  }
  
  rule on_bid_accepted {
    select when bid accepted
    pre {
      flowerShopEci = event:attrs{"flowerShopEci"}
      pickupTime = event:attrs{"pickupTime"}
      deliveryTime = event:attrs{"deliveryTime"}
      location = event:attrs{"location"}
      orderSequenceNumber = event:attrs{"orderSequenceNumber"}
    }
    always {
      ent:activeDelivery := {
        "flowerShopEci": flowerShopEci,
        "pickupTime": pickupTime,
        "deliveryTime": deliveryTime,
        "location": location,
        "orderSequenceNumber": orderSequenceNumber
      };
      raise driver event "start_pickup"
        attributes attributes
    }
  }
  
  rule on_start_pickup {
    select when driver start_pickup
    pre {
      pickupTime = ent:activeDelivery{"pickupTime"}
      nowPlusTimeToArrive = time:add(time:now(), {"seconds": locationToDistance()})
      shouldILeaveNow = (pickupTime < nowPlusTimeToArrive).klog("should I leave now pickup: ")
    }
    if shouldILeaveNow then 
      event:send({
        "eci": ent:activeDelivery{"flowerShopEci"},
        "eid": "none",
        "domain": "order",
        "type": "pickup",
        "attrs": {
          "driverEci": meta:eci,
          "orderSequenceNumber": ent:activeDelivery{"orderSequenceNumber"}
        }
      })
    fired {
      schedule driver event "start_delivery" at time:add(time:now(), {"seconds": locationToDistance()})
    } else {
      schedule driver event "start_pickup" at time:add(time:now(), {"seconds": 2})
    }
  }
  
  rule on_start_delivery {
    select when driver start_delivery
    pre {
      deliveryTime = ent:activeDelivery{"deliveryTime"}
      nowPlusTimeToArrive = time:add(time:now(), {"seconds": locationToDistance()})
      shouldILeaveNow = (deliveryTime < nowPlusTimeToArrive).klog("should I leave now delivery: ")
    }
    if shouldILeaveNow then noop()
    // also send text message using twilio
    fired {
      schedule driver event "finalize_delivery" at time:add(time:now(), {"seconds": locationToDistance()})
    } else {
      schedule driver event "start_delivery" at time:add(time:now(), {"seconds": 2})
    }
  }
  
  rule on_finalize_delivery {
    select when driver finalize_delivery
    pre {
      flowerShopEci = ent:activeDelivery{"flowerShopEci"}.klog("FINISHING DELIVERY WITH: ")
    }
    event:send({
      "eci": flowerShopEci,
      "eid": "none",
      "domain": "order",
      "type": "finalize",
      "attrs": {
        "driverEci": meta:eci,
        "orderSequenceNumber": ent:activeDelivery{"orderSequenceNumber"}
      }
    })
    always {
      ent:activeDelivery := null
    }
  }
  
  rule on_installation {
    select when wrangler ruleset_added where rids >< meta:rid
    pre {
    }
    noop()
    fired{
      ent:activeDelivery := null;
    }
  }
  
}
