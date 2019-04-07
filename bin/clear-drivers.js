const got = require("got");
const sensorEcis = [
  "LLXsSYfrSFwcbuf2CqPkmw",
  "8P6JbZ4fekSfKQ5kuaUwpy",
  "VxVnwDE4agLtZLazam2ZUH",
  "84HZRRPGX7hs8tX2ATRSoi",
  "S4v5FkNTHcQ7miVUHPA4PJ"
];

const baseEventUrl = `http://localhost:8080/sky/event/`;

sensorEcis.map(eci => got(`${baseEventUrl}${eci}/none/driver/clear`));
