const fs = require("fs");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  log("deployer:", deployer);

  // deploying UniswapV2Factory contract
  const factory = await deploy("UniswapV2Factory", {
    from: deployer,
    args: [deployer], // feeToSetter
    log: true,
  });
  log("UniswapV2Factory deployed to:", factory.address);

  // deploying Weth contract
  const weth = await deploy("WETH9", {
    from: deployer,
    args: [], 
    log: true,
  });
  log("WETH deployed to:", weth.address);

  const router = await deploy("UniswapV2Router02", {
    from: deployer,
    args: [factory.address, weth.address],
    log: true,
  });
  log("UniswapV2Router02 deployed to:", router.address);
};

module.exports.tags = ["all"];
