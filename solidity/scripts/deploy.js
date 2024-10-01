const hre = require('hardhat');

async function main() {
  // Deploy the TokenIdentifier contract
  const TokenIdentifier =
    await hre.ethers.getContractFactory('TokenIdentifier');
  const tokenIdentifier = await TokenIdentifier.deploy();
  await tokenIdentifier.deployed();
  console.log('TokenIdentifier deployed to:', tokenIdentifier.address);

  // Deploy the TokenTransfer contract
  const TokenTransfer = await hre.ethers.getContractFactory('TokenTransfer');
  const tokenTransfer = await TokenTransfer.deploy(tokenIdentifier.address);
  await tokenTransfer.deployed();

  // Deploy the GiftHolding contract
  const GiftHolding = await hre.ethers.getContractFactory('GiftHolding');
  const giftHolding = await GiftHolding.deploy(tokenIdentifier.address);
  await giftHolding.deployed();

  console.log('GiftHolding deployed to:', giftHolding.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
