const { ethers, upgrades } = require("hardhat");

const main = async () => {
  const BridgeFee1 = await ethers.getContractFactory("BridgeFee");

  console.log("Deploying the BridgeFee contract");
  const bf = await upgrades.deployProxy(BridgeFee1, [], {
    initializer: "initialize",
  });
};

main().catch;
