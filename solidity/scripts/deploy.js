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
  console.log('TokenTransfer deployed to:', tokenTransfer.address);

  // Deploy the GiftHolder contract
  const GiftHolder = await hre.ethers.getContractFactory('GiftHolder');
  const giftHolder = await GiftHolder.deploy(tokenIdentifier.address);
  await giftHolder.deployed();
  console.log('GiftHolder deployed to:', giftHolder.address);

  // Deploy the GiftManager contract
  const GiftManager = await hre.ethers.getContractFactory('GiftManager');
  const giftManager = await GiftManager.deploy(tokenIdentifier.address);
  await giftManager.deployed();
  console.log('GiftHolder deployed to:', giftManager.address);
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error);
    process.exit(1);
  });
