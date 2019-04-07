const got = require("got");
const driverEcis = [
  { eci: "LLXsSYfrSFwcbuf2CqPkmw", coordinate: "-111.675614,40.297440" }
  // { eci: "Lhuqy56VHLt1yzYZw292Ln", coordinate: "-111.682343,40.305793" },
  // { eci: "Lhuqy56VHLt1yzYZw292Ln", coordinate: "-111.649481,40.226231" }
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
