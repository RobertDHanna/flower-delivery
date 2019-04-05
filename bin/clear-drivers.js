const got = require("got");
const sensorEcis = [
  "LLXsSYfrSFwcbuf2CqPkmw",
  "Lhuqy56VHLt1yzYZw292Ln",
  "5fvbLkr3Hqs9cMsdpUwRYM"
];

const baseEventUrl = `http://localhost:8080/sky/event/`;

sensorEcis.map(eci => got(`${baseEventUrl}${eci}/none/driver/clear`));
