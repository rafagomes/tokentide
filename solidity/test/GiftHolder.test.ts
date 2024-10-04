import { TokenTransfer } from '../typechain-types/contracts/TokenTransfer';
import { MockERC721 } from '../typechain-types/contracts/mocks/MockERC721';
const { expect } = require('chai');
const { ethers } = require('hardhat');

describe('GiftHolder Contract (Unit Tests)', function () {
    let giftHolder;
    let tokenTransfer;
    let mockERC20;
    let mockERC721;
    let deployer;
    let addr1;
    let addr2;
    let recipientHash;
    let AUTHORIZED_ROLE;

    beforeEach(async () => {
        [deployer, addr1, addr2] = await ethers.getSigners();
        recipientHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('recipient@example.com'));
        AUTHORIZED_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('AUTHORIZED_ROLE'));

        // TokenIdentifier contract
        const TokenIdentifier = await ethers.getContractFactory('TokenIdentifier');
        const tokenIdentifier = await TokenIdentifier.deploy();
        await tokenIdentifier.deployed();

        // Mock TokenTransfer contract
        const TokenTransfer = await ethers.getContractFactory('TokenTransfer');
        tokenTransfer = await TokenTransfer.deploy(tokenIdentifier.address);
        await tokenTransfer.deployed();

        // Deploy the GiftHolder contract, passing in the mocked TokenTransfer contract
        const GiftHolder = await ethers.getContractFactory('GiftHolder');
        giftHolder = await GiftHolder.deploy(tokenTransfer.address);
        await giftHolder.deployed();

        // Deploy mock ERC20 token for testing
        const MockERC20 = await ethers.getContractFactory('MockERC20');
        mockERC20 = await MockERC20.deploy(ethers.utils.parseEther('1000')); // 1000 tokens
        await mockERC20.deployed();

        // Deploy mock ERC721 token for testing
        const MockERC721 = await ethers.getContractFactory('MockERC721');
        mockERC721 = await MockERC721.deploy(); // 1000 tokens
        await mockERC721.deployed();

        // Grant AUTHORIZED_ROLE to addr1
        await tokenIdentifier.grantRole(AUTHORIZED_ROLE, await tokenTransfer.address);
        await tokenTransfer.grantRole(AUTHORIZED_ROLE, await giftHolder.address);
        await giftHolder.grantRole(AUTHORIZED_ROLE, addr1.address);
    });

    describe('ERC20 Transfers', function () {
        const depositGiftHelper = async (signer, tokenAddress, amount, recipientEmail, fee) => {
            const recipientHash = ethers.utils.keccak256(ethers.utils.toUtf8Bytes(recipientEmail));
            await mockERC20.connect(deployer).transfer(signer.address, amount);
            await mockERC20.connect(signer).approve(tokenTransfer.address, amount);

            return {
                tx: await giftHolder
                    .connect(signer)
                    .depositGift(tokenAddress, recipientHash, amount, 0, fee),
                recipientHash,
            };
        };

        it('Should allow deposit and withdrawal of ERC20 tokens', async function () {
            const amount = ethers.utils.parseEther('100'); // 100 tokens

            // Transfer 100 tokens from deployer to addr1
            await mockERC20.connect(deployer).transfer(addr1.address, amount);

            // Approve the TokenTransfer contract to transfer tokens on behalf of addr1
            await mockERC20.connect(addr1).approve(tokenTransfer.address, amount);

            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient@example.com'),
            );

            // Deposit ERC20 tokens into the GiftHolder contract
            await expect(
                giftHolder
                    .connect(addr1)
                    .depositGift(mockERC20.address, recipientHash, amount, 0, 0),
            ).to.emit(giftHolder, 'GiftReceived');

            // Check that GiftHolder's balance increased
            const holderBalance = await mockERC20.balanceOf(giftHolder.address);
            expect(holderBalance).to.equal(amount);

            // Withdraw tokens back from GiftHolder using TokenTransfer (no need for approve)
            await expect(
                giftHolder.connect(addr1).claimGift(mockERC20.address, addr1.address, amount, 0),
            ).to.emit(giftHolder, 'GiftClaimProcessed');

            // Check that addr1 received the tokens back
            const addr1Balance = await mockERC20.balanceOf(addr1.address);
            expect(addr1Balance).to.equal(amount);
        });

        it('Should prevent unauthorized address from depositing tokens', async function () {
            const amount = ethers.utils.parseEther('100');
            await expect(
                depositGiftHelper(addr2, mockERC20.address, amount, 'recipient@example.com', 3),
            ).to.be.revertedWith('AccessControlUnauthorizedAccount');
        });
    });

    describe('ERC721 Transfers', function () {
        it('Should revert if trying to transfer ERC-721 without approval', async function () {
            await mockERC721.connect(deployer).mint(deployer.address);
            await expect(
                tokenTransfer.transferToken(mockERC721.address, deployer.address, addr2.address, 1),
            ).to.be.revertedWith('TransferFailed');
        });

        it('Should transfer ERC-721 tokens successfully with approval', async function () {
            await mockERC721.connect(deployer).mint(deployer.address);
            await mockERC721.connect(deployer).approve(tokenTransfer.address, 1);

            await expect(
                tokenTransfer.transferToken(mockERC721.address, deployer.address, addr2.address, 1),
            )
                .to.emit(mockERC721, 'Transfer')
                .withArgs(deployer.address, addr2.address, 1);

            expect(await mockERC721.ownerOf(1)).to.equal(addr2.address);
        });
    });

    describe('Claiming Gifts', function () {
        it('Should allow authorized address to claim ERC20 tokens', async function () {
            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient@example.com'),
            );

            const transferAmount = ethers.utils.parseEther('100');
            await mockERC20.transfer(giftHolder.address, transferAmount);
            await expect(
                giftHolder
                    .connect(addr1)
                    .claimGift(
                        mockERC20.address,
                        await addr1.getAddress(),
                        ethers.utils.parseEther('100'),
                        0,
                    ),
            ).to.emit(giftHolder, 'GiftClaimProcessed');
        });

        it('Should prevent unauthorized address from claiming tokens', async function () {
            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient@example.com'),
            );

            await expect(
                giftHolder
                    .connect(addr2)
                    .claimGift(
                        mockERC20.address,
                        await addr2.getAddress(),
                        ethers.utils.parseEther('100'),
                        0,
                    ),
            ).to.be.revertedWith('AccessControlUnauthorizedAccount');
        });
    });
});
