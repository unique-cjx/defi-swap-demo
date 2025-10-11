const fs = require("fs");

module.exports = async ({ getNamedAccounts, deployments }) => {
  const { deploy, log } = deployments;
  const { deployer } = await getNamedAccounts();

  const uniV2 = await deploy("UniswapV2Factory", {
    from: deployer,
    args: [deployer], // feeToSetter
    log: true,
  });

  log("UniswapV2Factory deployed to:", uniV2.address);
};

module.exports.tags = ["all"];
