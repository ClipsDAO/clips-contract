require("@nomiclabs/hardhat-waffle");

const HOME = require('os').homedir();
const fs = require("fs");
const infuraKey = "e468cafc35eb43f0b6bd2ab4c83fa688";
const privateKeys = JSON.parse(
  fs.readFileSync(`${HOME}/.hardhat.clips.accounts.json`).toString().trim()
);

function composeAccounts(network) {
  let keys = privateKeys;
  let localKeyFile = `./.local.${network}.secrets.json`;
  if (fs.existsSync(localKeyFile)) {
    let localKeys = JSON.parse(fs.readFileSync(localKeyFile).toString().trim());
    for (let x in keys) {
      localKeys.push(keys[x]);
    }
    keys = localKeys;
  }
  return keys;
}

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async () => {
  const accounts = await ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

/**
 * @type import('hardhat/config').HardhatUserConfig
 */
module.exports = {
  defaultNetwork: "localhost",
  networks: {
    hardhat: {},
    mainnet: {
      chainId: 1,
      url: `https://mainnet.infura.io/v3/${infuraKey}`,
      accounts: privateKeys,
      timeout: 200000,
    },
    ropsten: {
      chainId: 3,
      url: `https://ropsten.infura.io/v3/${infuraKey}`,
      accounts: privateKeys,
      timeout: 200000,
    },
    kovan: {
      chainId: 42,
      url: `https://kovan.infura.io/v3/${infuraKey}`,
      accounts: privateKeys,
      timeout: 200000,
    },
    binance_testnet: {
      chainId: 97,
      url: `https://data-seed-prebsc-1-s3.binance.org:8545/`,
      accounts: privateKeys,
      timeout: 200000,
    },
    binance_mainnet: {
      chainId: 56,
      url: "https://bsc-dataseed.binance.org/",
      accounts: privateKeys,
      timeout: 200000,
    },
    binance_composed_accounts: {
      chainId: 56,
      url: "https://bsc-dataseed.binance.org/",
      accounts: composeAccounts("binance"),
      timeout: 200000,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.6.12",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
      {
        version: "0.7.6",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  mocha: {
    timeout: 200000,
  },
};
