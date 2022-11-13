const { expect } = require("chai");
const { ethers, upgrades } = require("hardhat");

describe("BridgeFee Test", () => {
  let owner, signer1, signer2, bf, feeAddress, anyswapFactory;
  const NULL_ADDRESS = "0x0000000000000000000000000000000000000000";
  const multichainBNB = "0x13B432914A996b0A48695dF9B2d701edA45FF264"
  const multichainRouter = "0xBa8Da9dcF11B50B03fd5284f164Ef5cdEF910705"
  const anySwapToken = "0xf99d58e463A2E07e5692127302C20A191861b4D6"

  beforeEach(async () => {
    [owner, signer1, signer2, feeAddress] = await ethers.getSigners();

    anyswapFactory = await ethers.getContractAt("IERC20", anySwapToken)

    const BridgeFee1 = await ethers.getContractFactory("BridgeFee");

    bf = await upgrades.deployProxy(BridgeFee1, [], {
      initializer: "initialize",
      kind: "transparent",
    });
  });

  describe("Getter Functions", async () => {
    it("Should get the owner of the contract after deployment", async () => {
      expect(await bf.owner()).to.eq(owner.address);
    });
  });

  describe("Setter Functions", () => {
    it("Should revert when configure function is called by non-owner", async () => {
      const fee = [
        Number(ethers.utils.parseUnits("3", 3)),
        Number(ethers.utils.parseUnits("3", 2)),
      ];

      await expect(
        bf.connect(signer2).configure(feeAddress.address, fee)
      ).to.revertedWith("caller is not the owner");
    });

    it("Should revert when null address is passed as feeAddress", async () => {
      const fee = [
        Number(ethers.utils.parseUnits("3", 3)),
        Number(ethers.utils.parseUnits("3", 2)),
      ];

      await expect(
        bf.connect(owner).configure(NULL_ADDRESS, fee)
      ).to.revertedWith("invalid fee address");
    });

    it("Should successfully configure the feeAddress and fee info by owner", async () => {
      const fee = [
        Number(ethers.utils.parseUnits("3", 3)),
        Number(ethers.utils.parseUnits("3", 2)),
      ];

      await bf.connect(owner).configure(feeAddress.address, fee);
      expect(await bf.feeAddress()).to.eq(feeAddress.address);
    });

    it("Should reverts when owner intends to transfer ownership to null address", async () => {
        await expect(bf.transferOwnership(NULL_ADDRESS)).to.revertedWith("new owner is the zero address")
    })

    it("Should successfully transfer ownership from old to new address", async () => {
      await expect(bf.transferOwnership(signer1.address)).to.emit(bf, "OwnershipTransferred").withArgs(owner.address, signer1.address)
    })

    it("Should successfully set the Fee of a token address", async () => {
      const fee = [
        Number(ethers.utils.parseUnits("3", 3)),
        Number(ethers.utils.parseUnits("3", 2)),
      ];
      await bf.setTokenFee(anySwapToken, fee)
     const theFee = await bf.tokenFee(anySwapToken);
     expect(Number(theFee.value)).to.eq(Number(ethers.utils.parseUnits("3", 3)))
     expect(Number(theFee.precisions)).to.eq(Number(ethers.utils.parseUnits("3", 2))) 
    })
  });

  describe("Transfer", () => {
    it("Should revert if caller passes null address as dcrmAddress", async () => {
      await expect(bf.transfer(anySwapToken, "30000", NULL_ADDRESS)).to.revertedWith("invalid dcrm address")
    })

    it("Should revert if caller passes zero amount", async () => {
      await expect(bf.transfer(anySwapToken, "0", multichainBNB)).to.revertedWith("invalid amount")
    })

    it("Should successfully transfer tokens to the Anyswap Bridge and FeeAddress", async () => {
      // Set the token fee and feeAddress
      const fee = [
        Number(ethers.utils.parseUnits("3", 0)),
        Number(ethers.utils.parseUnits("3", 0)),
      ];

      await bf.connect(owner).configure(feeAddress.address, fee);

      // Set the caller through impersonation
      const prankAddr = "0x69927d1f0ad2b2ed72567ace8f4206af89c0632b"
      const amt = ethers.utils.parseEther("250")
      await hre.network.provider.request({
        method: "hardhat_impersonateAccount",
        params: [prankAddr],
      });
      const theSigner = await ethers.getSigner(prankAddr)

      // Approve to spend token for both multichain and feeaddress
      await anyswapFactory.connect(theSigner).approve(multichainBNB, amt)
      await anyswapFactory.connect(theSigner).approve(feeAddress.address, amt)

      // call transfer from BridgeFee Contract
      const value =  ethers.utils.parseUnits("7", 6)
      await bf.connect(theSigner).transfer(anySwapToken, value, multichainBNB)
     
    })
  })
});
