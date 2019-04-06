ruleset gossip {
  meta {
    shares __testing
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
    getPeer = function(state) {
      myPeers = state{"peers"}.klog("all peers: ");
      Subscription:established("Tx_role", "driver").klog("ALLLLL: ");
      peersThatNeedRumors = myPeers.filter(peerHasNotHeardAllRumors).klog("my filtered peers: ");
      (peersThatNeedRumors.length() > 0) => peersThatNeedRumors[random:integer(peersThatNeedRumors.length() - 1)] | null
    }
    prepareMessage = function(peer) {
      id = ent:eciToId{ peer{"Tx"} };
      potentialMessages = [];
      potentialMessages = peerHasNotHeardAllRumors(peer) => potentialMessages.append({"type": "rumor", "attrs": {"rumor": chooseRumorToSend(peer), "reply": meta:eci }}) | [];
      potentialMessages.klog("POTENTIAL: ");
      potentialMessages[random:integer(potentialMessages.length() - 1)]
    }
    chooseRumorToSend = function(peer) {
      id = ent:eciToId{ peer{"Tx"} };
      messagesSeenByPeer = ent:seen{id};
      chosenMessageID = ent:rumors.keys().filter(function(messageID) {
        justID = messageID.split(":")[0];
        sequenceNumber = messageID.split(":")[1].as("Number");
        not (messagesSeenByPeer >< justID && messagesSeenByPeer{justID} >= sequenceNumber)
      }).sort(function(a,b) {
        sequenceNumberA = a.split(":")[1].as("Number");
        sequenceNumberB = b.split(":")[1].as("Number");
        sequenceNumberA < sequenceNumberB => -1 |
        sequenceNumberA == sequenceNumberB => 0 |
                                              1
      }).head().klog("chosen message ID: ");
      ent:rumors{chosenMessageID}.klog("chosen rumor: ")
    }
    peerHasNotHeardAllRumors = function(peer) {
      id =  ent:eciToId{ peer{"Tx"} };
      messagesSeenByPeer = ent:seen{id}.klog("messages seen by peer: ");
      ent:rumors.keys().filter(function(messageID) {
        peer != null && id != messageID.split(":")[0]
      }).any(function(messageID) {
        justID = messageID.split(":")[0];
        sequenceNumber = messageID.split(":")[1].as("Number");
        not (messagesSeenByPeer >< justID && messagesSeenByPeer{justID} >= sequenceNumber)
      }).klog("rumors not heard: ")
    }
    getHighestSequenceNumberFromMessageID = function(messageID, startNumber) {
      id = messageID.split(":")[0];
      (ent:rumors >< id + ":" + startNumber) => getHighestSequenceNumberFromMessageID(messageID, startNumber + 1) | startNumber - 1
    }
  }
  rule on_bid_request {
    select when bid request
    pre {
      messageID = meta:picoId + ":" + ent:sequenceNumber.defaultsTo(0)
      flowerShopEci = event:attrs{"who"}
      pickupTime = event:attrs{"pickupTime"}.klog("[gossip] process pickup time: ")
      deliveryTime = event:attrs{"deliveryTime"}.klog("[gossip] process delivery time: ")
      location = event:attrs{"location"}
      orderSequenceNumber = event:attrs{"orderSequenceNumber"}
    }
    always {
      ent:seen{meta:picoId} := ent:seen{meta:picoId}.defaultsTo({}).put(meta:picoId, ent:sequenceNumber.defaultsTo(0));
      ent:rumors{messageID} := {
        "MessageID": messageID,
        "SensorID": meta:picoId,
        "flowerShopEci": flowerShopEci,
        "pickupTime": pickupTime,
        "deliveryTime": deliveryTime,
        "location": location,
        "orderSequenceNumber": orderSequenceNumber
      };
      ent:sequenceNumber := ent:sequenceNumber + 1;
      raise bid event "new_bid"
        attributes {
          "flowerShopEci": flowerShopEci,
          "pickupTime": pickupTime,
          "deliveryTime": deliveryTime,
          "location": location,
          "orderSequenceNumber": orderSequenceNumber
        }
    }
  }
  rule gossip_heartbeat {
    select when gossip heartbeat
    pre {
      wait_duration = ent:scheduleDelay;
      peer = getPeer({
        "peers": Subscription:established("Tx_role", "driver")
      }).klog("my peer: ");
      message = prepareMessage(peer).klog("my message: ");
    }
    
    if message != null then event:send({
      "eci": peer{"Tx"},
      "eid": "none",
      "domain": "gossip",
      "type": message{"type"},
      "attrs": message{"attrs"}
    })
    
    always {
      schedule gossip event "heartbeat" at time:add(time:now(), {"seconds": wait_duration})
    }
  }
  rule gossip_rumor {
    select when gossip rumor
    pre {
      messageID = event:attrs{"rumor"}{"MessageID"}
      eci = event:attrs{"reply"}
    }
    
    if ent:rumors >< messageID then event:send({
      "eci": eci,
      "eid": "none",
      "domain": "gossip",
      "type": "seen",
      "attrs": {
        "picoID": meta:picoId,
        "seen": ent:seen{meta:picoId}
      }
    })
    notfired {
      // we haven't seen this rumor before. let's make a bid if we can!
      rumor = event:attrs{"rumor"};
      raise bid event "new_bid"
        attributes {
          "flowerShopEci": rumor{"flowerShopEci"},
          "pickupTime": rumor{"pickupTime"},
          "deliveryTime": rumor{"deliveryTime"},
          "location": rumor{"location"},
          "orderSequenceNumber": rumor{"orderSequenceNumber"}
        }
    }
    finally {
      ent:rumors{messageID} := event:attrs{"rumor"};
      sequenceNumber = getHighestSequenceNumberFromMessageID(messageID, 0);
      ent:seen{meta:picoId} := ent:seen{meta:picoId}.defaultsTo({}).put(messageID.split(":")[0], (sequenceNumber == -1) => 0 | sequenceNumber );
    }
  }
  rule gossip_seen {
    select when gossip seen
    pre {
      picoID = event:attrs{"picoID"}
      whatHasBeenSeen = event:attrs{"seen"}
    }
    
    always {
      ent:seen{picoID} := whatHasBeenSeen
    }
  }
  rule on_installation {
    select when wrangler ruleset_added where rids >< meta:rid
    pre {
    }
    noop()
    fired{
      ent:eciToId := {};
      ent:rumors := {};
      ent:seen := {};
      ent:sequenceNumber := 0;
      ent:scheduleDelay := 5;
      raise gossip event "heartbeat"
        attributes event:attrs;
    }
  }
  rule on_new_subscription {
    select when wrangler subscription_added
    foreach Subscription:established("Tx_role", "driver") setting (subscription)
      pre {
        eci = subscription{"Tx"}
        whoAmI = subscription{"Rx"}
        myId = meta:picoId
      }
      // let my peers know my id
      event:send({
        "eci": eci,
        "edi": "eid",
        "domain": "gossip",
        "type": "accept_id",
        "attrs": {
          "id": myId,
          "who": whoAmI
        }
      })
  }
  rule clear_data {
    select when driver clear
    always {
      ent:rumors := {};
      ent:seen := {};
      ent:sequenceNumber := 0;
      ent:scheduleDelay := 2;
    }
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
  rule on_accept_id {
    select when gossip accept_id
    pre {
      id = event:attrs{"id"}
      who = event:attrs{"who"}
    }
    always {
      ent:eciToId{who} := id
    }
  }
}
