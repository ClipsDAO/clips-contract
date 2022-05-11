const { expect } = require("chai");

const {
  getBlockTimestamp,
  setBlockTime,
  increaseTime,
  mineBlocks,
  sync: { getCurrentTimestamp },
} = require("./helpers.js");

const D18 = ethers.BigNumber.from("1000000000000000000");
const D8 = ethers.BigNumber.from("100000000");
const D6 = ethers.BigNumber.from("1000000");

describe("Lock", function () {
  beforeEach(async function () {
    const [d, a, m, u1, u2, u3] = await ethers.getSigners();
    const Clips = await ethers.getContractFactory("Clips");
    const Lock = await ethers.getContractFactory("Lock");

    this.clips = await Clips.deploy(
      "CLIPS",
      "CLIPS",
      18,
      D18.mul(100000000),
      D18.mul(100000000)
    );

    this.lock = await Lock.deploy(this.clips.address, 60);
  });

  it("lock & release should work", async function () {
    const [d, a, m, u1, u2, u3] = await ethers.getSigners();

    let tx = await this.clips.mint(this.lock.address, D18.mul(10000));
    await tx.wait(1);

    tx = await this.lock.setup(u1.address, 0, D18.mul(1000), 10);
    await tx.wait(1);
    expect(await this.lock.canClaimOf(u1.address)).eq(0);
    expect(await this.lock.connect(u1).canClaim()).eq(0);
    expect(await this.lock.balanceOf(u1.address)).eq(D18.mul(1000));

    await this.lock.go();

    await increaseTime(60);
    await mineBlocks(1);

    expect(await this.lock.canClaimOf(u1.address)).eq(D18.mul(100));
    expect(await this.lock.connect(u1).canClaim()).eq(D18.mul(100));
    expect(await this.lock.balanceOf(u1.address)).eq(D18.mul(1000));

    tx = await this.lock.connect(u1).claim();
    await tx.wait(1);

    expect(await this.clips.balanceOf(u1.address)).eq(D18.mul(100));

    expect(await this.lock.canClaimOf(u1.address)).eq(0);
    expect(await this.lock.connect(u1).canClaim()).eq(0);
    expect(await this.lock.balanceOf(u1.address)).eq(D18.mul(900));

    await expect(this.lock.connect(u1).claim()).to.be.revertedWith("not ready");

    await increaseTime(540);
    await mineBlocks(1);

    expect(await this.lock.canClaimOf(u1.address)).eq(D18.mul(900));
    expect(await this.lock.connect(u1).canClaim()).eq(D18.mul(900));
    expect(await this.lock.balanceOf(u1.address)).eq(D18.mul(900));

    await increaseTime(540);
    await mineBlocks(1);
    await this.lock.connect(u1).claim();

    expect(await this.lock.canClaimOf(u1.address)).eq(0);
    expect(await this.lock.connect(u1).canClaim()).eq(0);
    expect(await this.lock.balanceOf(u1.address)).eq(0);
    expect(await this.clips.balanceOf(u1.address)).eq(D18.mul(1000));

    await increaseTime(600);
    await mineBlocks(1);

    expect(await this.lock.canClaimOf(u1.address)).eq(0);
    expect(await this.lock.connect(u1).canClaim()).eq(0);
    expect(await this.lock.balanceOf(u1.address)).eq(0);

    await expect(this.lock.connect(u1).claim()).to.be.revertedWith("not ready");
  });
});
