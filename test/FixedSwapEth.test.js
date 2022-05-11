const { expect } = require("chai");

const {
  getBlockTimestamp,
  setBlockTime,
  increaseTime,
  mineBlocks,
  sync: { getCurrentTimestamp },
} = require("./helpers.js");

const overrides = {
  gasPrice: ethers.utils.parseUnits("1", "gwei"),
  gasLimit: 8000000,
};

describe("FixedSwap", function () {
  const D8 = ethers.BigNumber.from("100000000");
  const D18 = ethers.BigNumber.from("1000000000000000000");
  const USDT_TOTAL = ethers.BigNumber.from("100000000000").mul(D8);
  const XYZ_TOTAL = ethers.BigNumber.from("20000000000000").mul(D18);

  beforeEach(async function () {
    const [deployer, other1, other2, other3] = await ethers.getSigners();
    console.log("other1 address:", other1.address);
    console.log("other2 address:", other2.address);
    console.log("other3 address:", other3.address);
    const XYZ = await ethers.getContractFactory("StakingToken");
    this.xyz = await XYZ.deploy("XYZ", "XYZ", 18, XYZ_TOTAL, XYZ_TOTAL);
    console.log("xyz address:", this.xyz.address);

    const xyzAmount = D18.mul(2000000);
    tx = await this.xyz.mint(xyzAmount, overrides);
    await tx.wait(1);

    // tx = await this.usdt.transfer(other1.address, D8.mul(100), overrides);
    // await tx.wait(1);
    // tx = await this.xyz.transfer(other1.address, D18.mul(1000), overrides);
    // await tx.wait(1);

    const FixedSwap = await ethers.getContractFactory("FixedSwap");
    this.fixedswap = await FixedSwap.deploy(
      345,
      "fixed_swap",
      deployer.address,
      "0x0000000000000000000000000000000000000000",
      this.xyz.address,
      500,
      other2.address,
      1617703853,
      1617870770
    );
    console.log("FixedSwap address", this.fixedswap.address);
    tx = await this.fixedswap.setQuota(other1.address, D18.mul(100));
    await tx.wait(1);

    // 向合约打入xyz
    tx = await this.xyz.transfer(this.fixedswap.address, D18.mul(120000), overrides);
    await tx.wait(1);

    // tx = await this.usdt.transfer(other1.address, D8.mul(100), overrides);
    // await tx.wait(1);
    // await this.usdt.connect(other1).approve(this.fixedswap.address, D8.mul(100));
    // await tx.wait(1);
    // tx = await this.fixedswap.connect(other1).offer(D8.mul(10), overrides);
    // await tx.wait(1);

    // await expect(this.fixedswap.connect(other1).offer(D8.mul(10), overrides))
    //   .to.emit(this.fixedswap, 'Offer')
    //   .withArgs(0);

    // await increaseTime(10000000);
    // tx = await this.fixedswap.connect(other1).claim(overrides);
    // await tx.wait(1);

    // expect(await this.xyz.balanceOf(other1.address)).to.eq(D18.mul(5000));
    // expect(await this.xyz.balanceOf(this.fixedswap.address)).to.eq(D18.mul(115000));
  });

  it("deploy uniswap", async function() {
    
  })
});
