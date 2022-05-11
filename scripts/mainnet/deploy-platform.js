// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// When running the script with `hardhat run <script>` you'll find the Hardhat
// Runtime Environment's members available in the global scope.
const hre = require("hardhat");
const { ethers } = hre;

const D18 = ethers.BigNumber.from("1000000000000000000");
const D6 = ethers.BigNumber.from(1000000);
const D8 = ethers.BigNumber.from("100000000");

const fs = require("fs");
const overrides = {
  gasPrice: ethers.utils.parseUnits("5", "gwei"),
  gasLimit: 8000000,
};

async function main() {
  const [deployer, zeus] = await ethers.getSigners();
  const Platform = await ethers.getContractFactory("Platform");
  const FixedSwapFactory = await ethers.getContractFactory("FixedSwapFactory");
  const UnlimitedProrateFactory = await ethers.getContractFactory("UnlimitedProrateFactory");
  const Proxy = await ethers.getContractFactory("TransparentUpgradeableProxy");

  let tx;

  let platform = await Platform.deploy(overrides);
  await platform.deployed();
  console.log("platform impl deployed: ", platform.address);

  const platformInitialize = Platform.interface.getFunction(
    "initialize(address,string)"
  );
  const platformInitializeCalldata = Platform.interface.encodeFunctionData(
    platformInitialize,
    [zeus.address, "CLIPS"]
  );
  const platformProxy = await Proxy.deploy(
    platform.address,
    deployer.address,
    platformInitializeCalldata,
    overrides
  );
  await platformProxy.deployed();
  platform = Platform.attach(platformProxy.address).connect(zeus);
  console.log("platform is deployed: ", platform.address);

  let fixedfactory = await FixedSwapFactory.deploy(platform.address, overrides);
  await fixedfactory.deployed();
  let unlimitedfactory = await UnlimitedProrateFactory.deploy(platform.address, overrides);
  await unlimitedfactory.deployed();
  console.log(`factory deployed: ${fixedfactory.address}, ${unlimitedfactory.address}`)

  tx = await platform.addTemplate(0, fixedfactory.address);
  await tx.wait(1);
  tx = await platform.addTemplate(1, unlimitedfactory.address);
  await tx.wait(1);
  console.log("factory set");
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
