const got = require("got");
const shopEcis = ["HuD3jq7cDAhPgCcLabmJqp", "ASYXHLyAapsjLdjvWhKi9C"];

const baseEventUrl = `http://localhost:8080/sky/event/`;

shopEcis.map(eci =>
  got(`${baseEventUrl}${eci}/none/order/new`, {
    json: true,
    body: {
      pickupTime: new Date(),
      deliveryTime: new Date()
    }
  })
);
