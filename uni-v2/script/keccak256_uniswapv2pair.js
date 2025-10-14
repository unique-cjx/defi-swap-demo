const fs = require("fs");
const { keccak256 } = require("ethers");

// we need to get the bytecode of the UniswapV2Pair contract
// and write it to a file so that we can use it in our tests
// we can get the bytecode from the artifacts folder
// the path is: ./artifacts/contracts/UniswapV2Pair.sol/UniswapV2Pair.json
//
// we need to remove the "0x" prefix from the bytecode
// and write it to a file called pair_creation_bytecode.txt
async function main() {
  const path = "./artifacts/contracts/UniswapV2Pair.sol/UniswapV2Pair.json";
  if (!fs.existsSync(path)) {
    throw new Error(`File not found: ${path}`);
  }

  const UniswapV2PairJson = JSON.parse(fs.readFileSync(path, "utf8"));

  fs.writeFileSync("./artifacts/pair_creation_bytecode.txt", UniswapV2PairJson.bytecode.slice(2));

  const hex = "0x" + fs.readFileSync("./artifacts/pair_creation_bytecode.txt", "utf8").trim();

  console.log(keccak256(hex));
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error("main error:", error);
    process.exit(1);
  });
