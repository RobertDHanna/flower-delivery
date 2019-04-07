ruleset flower_shop {
  meta {
    shares __testing, orders, drivers
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
    drivers = function() {
      ent:driverStatus
    }
    selectBidder = function(bidders) {
      bidders.klog("my bidders: ");
      sortedByClosest = bidders.filter(function(bidder) {
        ent:driverStatus{bidder{"driverEci"}} == "free" || ent:driverStatus{bidder{"driverEci"}} == null
      }).sort(function(a, b) {
        a{"estimatedDeliveryTime"} < b{"estimatedDeliveryTime"} => -1 |
        a{"estimatedDeliveryTime"} == b{"estimatedDeliveryTime"} => 0 |
                                                                    1
      }).klog("sorted by closest: ");
      sliceLength = sortedByClosest.length() > 3 => 3 | sortedByClosest.length() - 1;
      topThreeChoices = sortedByClosest.slice(sliceLength).klog("top three choices: ");
      topThreeChoices[random:integer(topThreeChoices.length() - 1)].klog("our choice: ")
    }
  }
  
  rule on_finalize_order {
    select when order finalize
    pre {
      driverEci = event:attrs{"driverEci"}
      orderSequenceNumber = event:attrs{"orderSequenceNumber"}
      order = ent:orderMap{orderSequenceNumber}
    }
    always {
      ent:orderMap{[orderSequenceNumber, "deliveryStatus"]} := "delivered";
      ent:driverStatus{driverEci} := "free"
    }
  }
  
  rule on_choose_bidder {
    select when order choose_bidder
    pre {
      orderSequenceNumber = event:attrs{"orderSequenceNumber"}
      pickedDriver = selectBidder(ent:orderMap{[orderSequenceNumber, "bids"]})
      pickupTime = ent:orderMap{orderSequenceNumber}{"pickupTime"}
      deliveryTime = ent:orderMap{orderSequenceNumber}{"deliveryTime"}
      location = ent:orderMap{orderSequenceNumber}{"location"}
      flowerShopCoordinate = ent:orderMap{orderSequenceNumber}{"flowerShopCoordinate"}
      orderCoordinate = ent:orderMap{orderSequenceNumber}{"orderCoordinate"}
    }
    if pickedDriver != null then event:send({
      "eci": pickedDriver{"driverEci"},
      "edi": "eid",
      "domain": "bid",
      "type": "accepted",
      "attrs": {
        "flowerShopEci": meta:eci,
        "pickupTime": pickupTime,
        "deliveryTime": deliveryTime,
        "location": location,
        "orderSequenceNumber": orderSequenceNumber,
        "flowerShopCoordinate": flowerShopCoordinate,
        "orderCoordinate": orderCoordinate
      }
    })
    fired {
      ent:orderMap{[orderSequenceNumber, "selectedDriver"]} := pickedDriver{"driverEci"};
      ent:orderMap{[orderSequenceNumber, "deliveryStatus"]} := "out for pickup";
      ent:driverStatus{pickedDriver{"driverEci"}} := "picking up order"
    } else {
      // raise order event "broadcast" attributes {
      //   "pickupTime": pickupTime,
      //   "deliveryTime": deliveryTime,
      //   "location": location,
      //   "orderSequenceNumber": orderSequenceNumber
      // };
      raise order event "reschedule" attributes { "orderSequenceNumber": orderSequenceNumber }
    }
  }
  
  rule on_reschedule_bid_choosing {
    select when order reschedule
    pre {
      orderSequenceNumber = event:attrs{"orderSequenceNumber"}
      orderAvailable = ent:orderMap.values().filter(function(order) {
        order{"deliveryStatus"} == "not delivered"
      }).length() > 0
    }
    if orderAvailable then noop()
    fired {
      schedule order event "choose_bidder" at time:add(time:now(), {"seconds": 5}) attributes {
        "orderSequenceNumber": orderSequenceNumber
      }
    }
  }
  
  rule on_driver_pickup_status {
    select when order pickup
    pre {
      driverEci = event:attrs{"driverEci"}
      orderSequenceNumber = event:attrs{"orderSequenceNumber"}
    }
    always {
      ent:driverStatus{driverEci} := "out for delivery"
    }
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
      pickupTime = time:add(time:now(), {"seconds": 15})
      deliveryTime = time:add(time:now(), {"seconds": 30})
      myCoordinate = "-111.687854,40.296484"
      orderCoordinate = "-111.649701,40.226665"
     }
    always {
      order = { 
        "orderSequenceNumber": ent:orderSequenceNumber, 
        "selectedDriver": null,
        "deliveryStatus": "not delivered",
        "pickupTime": pickupTime, 
        "deliveryTime": deliveryTime,
        "location": "not implemented",
        "bids": [],
        "flowerShopCoordinate": myCoordinate,
        "orderCoordinate": orderCoordinate
      };
      ent:orderMap{ent:orderSequenceNumber} := order;
      ent:orderSequenceNumber := ent:orderSequenceNumber + 1;
      raise order event "broadcast"
        attributes order;
      schedule order event "choose_bidder" at time:add(time:now(), {"seconds": 15}) attributes {
        "orderSequenceNumber": ent:orderSequenceNumber - 1
      }
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
        flowerShopCoordinate = event:attrs{"flowerShopCoordinate"}
        orderCoordinate = event:attrs{"orderCoordinate"}
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
          "orderSequenceNumber": orderSequenceNumber,
          "flowerShopCoordinate": flowerShopCoordinate,
          "orderCoordinate": orderCoordinate
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
      ent:driverStatus := {};
    }
  }
}
