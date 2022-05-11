const { expect } = require("chai");
const { ethers } = require("hardhat");

const {
  getBlockTimestamp,
  setBlockTime,
  increaseTime,
  mineBlocks,
  sync: { getCurrentTimestamp },
} = require("./helpers.js");

describe("FixedSwap", function () {
  const D8 = ethers.BigNumber.from("100000000");
  const D18 = ethers.BigNumber.from("1000000000000000000");
  const USDT_TOTAL = ethers.BigNumber.from("100000000000").mul(D8);
  const XYZ_TOTAL = ethers.BigNumber.from("20000000000000").mul(D18);

  const overrides = {
    gasPrice: ethers.utils.parseUnits("1", "gwei"),
    gasLimit: 8000000,
  };

  beforeEach(async function () {
  });

  it("over-raised", async function() {
    const [deployer, other1, other2, other3] = await ethers.getSigners();
    console.log("other1 address:", other1.address);
    console.log("other2 address:", other2.address);
    console.log("other3 address:", other3.address);
    const USDT = await ethers.getContractFactory("StakingToken");
    this.usdt = await USDT.deploy("USDT", "USDT", 8, USDT_TOTAL, USDT_TOTAL);
    console.log("usdt address:", this.usdt.address);
    const XYZ = await ethers.getContractFactory("StakingToken");
    this.xyz = await XYZ.deploy("XYZ", "XYZ", 18, XYZ_TOTAL, XYZ_TOTAL);
    console.log("xyz address:", this.xyz.address);

    const usdtAmount = D8.mul(10000);
    tx = await this.usdt.mint(usdtAmount, overrides);
    await tx.wait(1);

    const xyzAmount = D18.mul(2000000);
    tx = await this.xyz.mint(xyzAmount, overrides);
    await tx.wait(1);

    // tx = await this.usdt.transfer(other1.address, D8.mul(100), overrides);
    // await tx.wait(1);
    // tx = await this.xyz.transfer(other1.address, D18.mul(1000), overrides);
    // await tx.wait(1);

    const SealedBid = await ethers.getContractFactory("SealedBid");
    this.sealedbidswap = await SealedBid.deploy(
      345,
      "sealed_bid",
      deployer.address,
      "0x0000000000000000000000000000000000000000",
      this.xyz.address,
      3,
      1618048214,
      1618048214
    );
    console.log("SealedBidSwap address", this.sealedbidswap.address);
    // tx = await this.fixedswap.setQuota(other1.address, D8.mul(100));
    // await tx.wait(1);

    // 向合约打入xyz
    tx = await this.xyz.transfer(this.sealedbidswap.address, D18.mul(100), overrides);
    await tx.wait(1);

    tx = await this.sealedbidswap.connect(other1).purchaseHT({
      gasPrice: ethers.utils.parseUnits("1", "gwei"),
      gasLimit: 8000000,
      value: ethers.utils.parseEther("120")
    });
    await tx.wait(1);

    tx = await this.sealedbidswap.connect(other2).purchaseHT({
      gasPrice: ethers.utils.parseUnits("1", "gwei"),
      gasLimit: 8000000,
      value: ethers.utils.parseEther("120")
    });
    await tx.wait(1);

    tx = await this.sealedbidswap.connect(other3).purchaseHT({
      gasPrice: ethers.utils.parseUnits("1", "gwei"),
      gasLimit: 8000000,
      value: ethers.utils.parseEther("120")
    });
    await tx.wait(1);

    await increaseTime(100000);
    tx = await this.sealedbidswap.connect(other1).settle(overrides);
    await tx.wait(1);
    // tx = await this.sealedbidswap.connect(other2).settle(overrides);
    // await tx.wait(1);

    await expect(this.sealedbidswap.connect(other3).settle(overrides))
      .to.emit(this.sealedbidswap, 'Settle')
      .withArgs(other3.address, 2000040000, 3333320, 83333);

      // expect(await this.xyz.balanceOf(other1.address)).to.eq(33333200000000000000);
  })
});
