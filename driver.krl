ruleset driver {
  meta {
    use module apis_and_picos.keys
    use module mapbox_wrapper alias mapbox
          with access_token = keys:mapbox{"access_token"}
    use module apis_and_picos.twilio_wrapper alias twilio
        with account_sid = keys:twilio{"account_sid"}
             auth_token =  keys:twilio{"auth_token"}
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
    driverNum = "+1801555555"
    locationToDistance = function(otherCoordinate) {
      ent:myCoordinate.klog("my coordinate: ");
      otherCoordinate.klog("other coordinate: ");
      duration = (mapbox:getDuration(ent:myCoordinate, otherCoordinate){"durations"}[0][1] / 60).klog("mapbox response: ");
      ((duration < 5) => random:integer(10) + 1 | duration).klog("duration returned: ")
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
  
  rule bid_heartbeat {
    select when bid heartbeat
    pre {
      bid = ent:bidList.head()
    }
    if ent:activeDelivery == null && bid != null then event:send({
        "eci": bid{"flowerShopEci"},
        "eid": "none",
        "domain": "bid",
        "type": "process",
        "attrs": {
          "driverEci": meta:eci,
          "bidAmount": pickBidAmount(),
          "estimatedDeliveryTime": locationToDistance(bid{"orderCoordinate"}),
          "orderSequenceNumber": bid{"orderSequenceNumber"}
        }
    })
    fired {
      ent:bidList := ent:bidList.filter(function(_bid) {
        bid{"orderSequenceNumber"} != _bid{"orderSequenceNumber"}
      });
    }
    finally {
     schedule bid event "heartbeat" at time:add(time:now(), {"seconds": 3})
   }
  }
  
  rule on_new_bid {
    select when bid new_bid
    pre {
      flowerShopEci = event:attrs{"flowerShopEci"}
      pickupTime = event:attrs{"pickupTime"}
      deliveryTime = event:attrs{"deliveryTime"}
      location = event:attrs{"location"}
      orderSequenceNumber = event:attrs{"orderSequenceNumber"}
      flowerShopCoordinate = event:attrs{"flowerShopCoordinate"}
      orderCoordinate = event:attrs{"orderCoordinate"}
    }
    always {
      ent:bidList := ent:bidList.append({
        "flowerShopEci": flowerShopEci,
        "pickupTime": pickupTime,
        "deliveryTime": deliveryTime,
        "location": location,
        "orderSequenceNumber": orderSequenceNumber,
        "flowerShopCoordinate": flowerShopCoordinate,
        "orderCoordinate": orderCoordinate
      })
    }
  }
  
  rule on_bid_accepted {
    select when bid accepted
    pre {
      flowerShopEci = event:attrs{"flowerShopEci"}
      pickupTime = event:attrs{"pickupTime"}
      deliveryTime = event:attrs{"deliveryTime"}
      location = event:attrs{"location"}
      orderSequenceNumber = event:attrs{"orderSequenceNumber"}
      flowerShopCoordinate = event:attrs{"flowerShopCoordinate"}
      orderCoordinate = event:attrs{"orderCoordinate"}
    }
    if ent:activeDelivery != null then 
      event:send({
        "eci": ent:activeDelivery{"flowerShopEci"},
        "eid": "none",
        "domain": "driver",
        "type": "busy",
        "attrs": {
          "driverEci": meta:eci,
          "orderSequenceNumber": ent:activeDelivery{"orderSequenceNumber"}
        }
      })
    notfired {
      ent:activeDelivery := {
        "flowerShopEci": flowerShopEci,
        "pickupTime": pickupTime,
        "deliveryTime": deliveryTime,
        "location": location,
        "orderSequenceNumber": orderSequenceNumber,
        "timeToFlowerShop": locationToDistance(flowerShopCoordinate),
        "timeToCustomer": locationToDistance(orderCoordinate)
      };
      raise driver event "start_pickup"
        attributes attributes
    }
  }
  
  rule on_start_pickup {
    select when driver start_pickup
    pre {
      pickupTime = ent:activeDelivery{"pickupTime"}
      nowPlusTimeToArrive = time:add(time:now(), {"seconds": ent:activeDelivery{"timeToFlowerShop"}.klog("time to flower shop: ")})
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
      schedule driver event "start_delivery" at time:add(time:now(), {"seconds": ent:activeDelivery{"timeToFlowerShop"}})
    } else {
      schedule driver event "start_pickup" at time:add(time:now(), {"seconds": 2})
    }
  }
  
  rule on_start_delivery {
    select when driver start_delivery
    pre {
      deliveryTime = ent:activeDelivery{"deliveryTime"}
      nowPlusTimeToArrive = time:add(time:now(), {"seconds": ent:activeDelivery{"timeToCustomer"}.klog("time to customer: ")})
      shouldILeaveNow = (deliveryTime < nowPlusTimeToArrive).klog("should I leave now delivery: ")
    }
    if shouldILeaveNow then noop()
      // twilio:send_sms(
      //   ent:activeDelivery{"toNum"},
      //   driverNum,
      //   "Your order is our for delivery!"
      // )
    // also send text message using twilio
    fired {
      schedule driver event "finalize_delivery" at time:add(time:now(), {"seconds": ent:activeDelivery{"timeToCustomer"}})
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
  
  rule clear_data {
    select when driver clear
    always {
      ent:activeDelivery := null;
      ent:bidList := [];
    }
  }
  
  rule on_set_coordinate {
    select when coordinate set
    pre {
      coordinate = event:attrs{"coordinate"}
    }
    always {
      ent:myCoordinate := coordinate
    }
  }
  
  rule on_installation {
    select when wrangler ruleset_added where rids >< meta:rid
    pre {
    }
    noop()
    fired{
      ent:activeDelivery := null;
      ent:bidList := [];
      ent:myCoordinate := "";
      raise bid event "heartbeat"
        attributes attributes
    }
  }
  
}
