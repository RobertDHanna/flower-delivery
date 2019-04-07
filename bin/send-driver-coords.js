const got = require("got");
const driverEcis = [
  { eci: "LLXsSYfrSFwcbuf2CqPkmw", coordinate: "-111.696310,40.233226" },
  { eci: "8P6JbZ4fekSfKQ5kuaUwpy", coordinate: "-111.615940,40.189968" },
  { eci: "VxVnwDE4agLtZLazam2ZUH", coordinate: "-111.664243,40.314227" },
  { eci: "84HZRRPGX7hs8tX2ATRSoi", coordinate: "-111.704305,40.329673" },
  { eci: "S4v5FkNTHcQ7miVUHPA4PJ", coordinate: "-111.702995,40.241362" }
];

const flowerShopEcis = [
  { eci: "HuD3jq7cDAhPgCcLabmJqp", coordinate: "-111.679708,40.250096" },
  { eci: "ASYXHLyAapsjLdjvWhKi9C", coordinate: "-111.657286,40.236924" }
];

const baseEventUrl = `http://localhost:8080/sky/event/`;

driverEcis.map(driver =>
  got(`${baseEventUrl}${driver.eci}/none/coordinate/set`, {
    json: true,
    body: {
      coordinate: driver.coordinate
    }
  })
);

flowerShopEcis.map(flowerShop =>
  got(`${baseEventUrl}${flowerShop.eci}/none/coordinate/set`, {
    json: true,
    body: {
      coordinate: flowerShop.coordinate
    }
  })
);
