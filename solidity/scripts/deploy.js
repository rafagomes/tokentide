const hre = require('hardhat');

async function main() {
    // Set the owner address
    const [deployer] = await hre.ethers.getSigners();
    console.log('Deployer address:', deployer.address);

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

    // permissions set
    // Grant AUTHORIZED_ROLE to TokenTransfer in TokenIdentifier
    const AUTHORIZED_ROLE = ethers.utils.keccak256(
        ethers.utils.toUtf8Bytes('AUTHORIZED_ROLE'),
    );
    await tokenIdentifier
        .connect(deployer)
        .grantRole(AUTHORIZED_ROLE, tokenTransfer.address);
    console.log(
        `Granted AUTHORIZED_ROLE of tokenIdentifier to TokenTransfer at address ${tokenTransfer.address}`,
    );

    // Deploy the GiftHolder contract
    const GiftHolder = await hre.ethers.getContractFactory('GiftHolder');
    const giftHolder = await GiftHolder.deploy(tokenIdentifier.address);
    await giftHolder.deployed();
    console.log('GiftHolder deployed to:', giftHolder.address);

    // Deploy the GiftManager contract
    const GiftManager = await hre.ethers.getContractFactory('GiftManager');
    const giftManager = await GiftManager.deploy(
        tokenTransfer.address,
        giftHolder.address,
    );
    await giftManager.deployed();
    console.log('GiftManager deployed to:', giftManager.address);

    // Permissions set
    await tokenTransfer
        .connect(deployer)
        .grantRole(AUTHORIZED_ROLE, giftManager.address);
    console.log(
        `Granted AUTHORIZED_ROLE of tokenTransfer to GiftManager at address ${giftManager.address} in TokenTransfer`,
    );

    await giftHolder
        .connect(deployer)
        .grantRole(AUTHORIZED_ROLE, giftManager.address);
    console.log(
        `Granted AUTHORIZED_ROLE of giftHolder to GiftManager at address ${giftManager.address} in GiftHolder`,
    );
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
