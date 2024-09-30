import { HardhatUserConfig } from 'hardhat/config';
import '@nomiclabs/hardhat-ethers';
import '@nomiclabs/hardhat-waffle';
import '@typechain/hardhat';
import '@nomiclabs/hardhat-etherscan';

const config: HardhatUserConfig = {
  solidity: '0.8.27',
  networks: {
    hardhat: {},
    localhost: {
      url: 'http://127.0.0.1:8545',
      // You can set the accounts field to use the private keys provided by the node, but Hardhat does this by default
    },
  },
  paths: {
    sources: './contracts',
    tests: './test',
    cache: './cache',
    artifacts: './artifacts',
  },
};

export default config;
