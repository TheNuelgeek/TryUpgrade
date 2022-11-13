require("@nomicfoundation/hardhat-toolbox");
require("@nomiclabs/hardhat-ethers");
require("@openzeppelin/hardhat-upgrades");
require("@nomiclabs/hardhat-etherscan");

require("dotenv").config();

/** @type import('hardhat/config').HardhatUserConfig */
module.exports = {
  solidity: "0.8.4",
  networks: {
    hardhat: {
      forking: {
        url: "https://frosty-capable-dawn.discover.quiknode.pro/377885d856c6ce1430b4b3c5be1f924d756e9d12/",
        blockNumber: 15963230
      }
    }
  }
};
