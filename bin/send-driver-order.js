const got = require("got");
const driverEcis = [
  //   "LLXsSYfrSFwcbuf2CqPkmw"
  "Lhuqy56VHLt1yzYZw292Ln"
  // "CtDcLTyCQgMqikdNoTu7v7"
  // "JsRPGa8QtEGsHVjjL5QVnL"
];

const baseEventUrl = `http://localhost:8080/sky/event/`;

driverEcis.map(eci =>
  got(`${baseEventUrl}${eci}/none/bid/request`, {
    json: true,
    body: {
      pickupTime: new Date(),
      deliveryTime: new Date()
    }
  })
);
