const fs = require("fs");
const args = process.argv.slice(2);

if (args.length < 2) {
  console.log(
    "Error: Must include file name to parse and number of driver coordinates"
  );
  process.exit(0);
}

const coordsFile = args[0];
const numberOfDriverCoords = args[1];

let contents;
try {
  contents = fs.readFileSync(coordsFile, { encoding: "utf-8" });
} catch (e) {
  console.log("Error: could not read coords file", e);
  process.exit(0);
}

/**
 * Randomly shuffle an array
 * https://stackoverflow.com/a/2450976/1293256
 * @param  {Array} array The array to shuffle
 * @return {String}      The first item in the shuffled array
 */
var shuffle = function(array) {
  var currentIndex = array.length;
  var temporaryValue, randomIndex;

  // While there remain elements to shuffle...
  while (0 !== currentIndex) {
    // Pick a remaining element...
    randomIndex = Math.floor(Math.random() * currentIndex);
    currentIndex -= 1;

    // And swap it with the current element.
    temporaryValue = array[currentIndex];
    array[currentIndex] = array[randomIndex];
    array[randomIndex] = temporaryValue;
  }

  return array;
};

const sanitizedContents = shuffle(
  contents.split("\n").map(item => item.trim())
).join("\n");

const driverCoords = sanitizedContents
  .split("\n")
  .slice(0, numberOfDriverCoords)
  .join("\n");

const orderCoords = sanitizedContents
  .split("\n")
  .slice(numberOfDriverCoords)
  .join("\n");

fs.writeFile("bin/driverCoords.txt", driverCoords, err => {
  if (err) throw err;
  console.log("Driver Coords Saved");
});

fs.writeFile("bin/orderCoords.txt", orderCoords, err => {
  if (err) throw err;
  console.log("Order Coords Saved");
});
