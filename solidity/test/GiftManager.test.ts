import { ethers } from 'hardhat';
import { Contract } from 'ethers';
import chai from 'chai';
import { solidity } from 'ethereum-waffle';

chai.use(solidity);
const { expect } = chai;

describe('GiftManager Contract', function () {
    let giftManager: Contract;
    let giftHolder: Contract;
    let tokenTransfer: Contract;
    let mockERC20: Contract;
    let mockERC721: Contract;
    let deployer, addr1, addr2;
    let AUTHORIZED_ROLE;

    before(async () => {
        [deployer, addr1, addr2] = await ethers.getSigners();
        AUTHORIZED_ROLE = ethers.utils.keccak256(ethers.utils.toUtf8Bytes('AUTHORIZED_ROLE'));

        // Deploy TokenIdentifier contract
        const TokenIdentifier = await ethers.getContractFactory('TokenIdentifier');
        const tokenIdentifier = await TokenIdentifier.deploy();
        await tokenIdentifier.deployed();

        // Deploy TokenTransfer contract
        const TokenTransfer = await ethers.getContractFactory('TokenTransfer');
        tokenTransfer = await TokenTransfer.deploy(tokenIdentifier.address);
        await tokenTransfer.deployed();

        // Deploy GiftHolder contract
        const GiftHolder = await ethers.getContractFactory('GiftHolder');
        giftHolder = await GiftHolder.deploy(tokenTransfer.address);
        await giftHolder.deployed();

        // Deploy GiftManager contract
        const GiftManager = await ethers.getContractFactory('GiftManager');
        giftManager = await GiftManager.deploy(tokenTransfer.address, giftHolder.address);
        await giftManager.deployed();

        // Deploy mock ERC20 and ERC721 for testing
        const MockERC20 = await ethers.getContractFactory('MockERC20');
        mockERC20 = await MockERC20.deploy(ethers.utils.parseEther('1000')); // 1000 tokens
        await mockERC20.deployed();

        const MockERC721 = await ethers.getContractFactory('MockERC721');
        mockERC721 = await MockERC721.deploy();
        await mockERC721.deployed();

        await tokenIdentifier.grantRole(AUTHORIZED_ROLE, giftManager.address);
        await tokenIdentifier.grantRole(AUTHORIZED_ROLE, tokenTransfer.address);

        await tokenTransfer.grantRole(AUTHORIZED_ROLE, giftHolder.address);
        await tokenTransfer.grantRole(AUTHORIZED_ROLE, giftManager.address);

        await giftHolder.grantRole(AUTHORIZED_ROLE, giftManager.address);
        await giftManager.grantRole(AUTHORIZED_ROLE, addr1.address);

        const amount = ethers.utils.parseEther('10');
        await mockERC20.connect(deployer).transfer(addr1.address, amount);
    });

    describe('Depositing Gifts', function () {
        it('Should deposit an ERC20 gift', async function () {
            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient@example.com'),
            );
            const amount = ethers.utils.parseEther('10');

            // Approve the GiftManager contract to transfer tokens on behalf of addr1
            await mockERC20.connect(addr1).approve(tokenTransfer.address, amount);

            // Deposit ERC20 tokens
            await expect(
                giftManager
                    .connect(addr1)
                    .depositGift(mockERC20.address, recipientHash, amount, 60 * 60),
            ).to.emit(giftManager, 'GiftDeposited');

            // Verify the balance of the giftHolder contract
            const giftHolderBalance = await mockERC20.balanceOf(giftHolder.address);
            expect(giftHolderBalance).to.equal(amount);
        });

        it('Should revert if the gift already exists', async function () {
            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient@example.com'),
            );
            const amount = ethers.utils.parseEther('10');

            // Try to deposit the same gift again
            await expect(
                giftManager
                    .connect(addr1)
                    .depositGift(mockERC20.address, recipientHash, amount, 60 * 60),
            ).to.be.revertedWith('GiftAlreadyExists');
        });
    });

    describe('Claiming Gifts', function () {
        it('Should allow claiming a gift', async function () {
            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient@example.com'),
            );
            const claimAmount = ethers.utils.parseEther('10');

            // Claim the gift
            await expect(giftManager.connect(addr1).claimGift(recipientHash)).to.emit(
                giftManager,
                'GiftClaimed',
            );

            // Check that the balance of addr1 has increased
            const addr1Balance = await mockERC20.balanceOf(addr1.address);
            expect(addr1Balance).to.equal(claimAmount);
        });

        it('Should revert if trying to claim an already claimed gift', async function () {
            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient@example.com'),
            );

            // Attempt to claim the gift again
            await expect(giftManager.connect(addr1).claimGift(recipientHash)).to.be.revertedWith(
                'GiftNotFound',
            );
        });
    });

    describe('Reclaiming Gifts', function () {
        it('Should allow reclaiming an expired gift', async function () {
            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('expired@example.com'),
            );
            const amount = ethers.utils.parseEther('10');

            // Approve and deposit the gift
            await mockERC20.connect(addr1).approve(tokenTransfer.address, amount);

            await giftManager.connect(addr1).depositGift(
                mockERC20.address,
                recipientHash,
                amount,
                1, // Expire in 1 second
            );

            await new Promise((resolve) => setTimeout(resolve, 3000)); // 3-second delay to ensure expiration
            await expect(giftManager.connect(addr1).reclaimGift(recipientHash)).to.emit(
                giftManager,
                'GiftClaimed',
            );

            // Verify that the balance has been returned to addr1
            const addr1Balance = await mockERC20.balanceOf(addr1.address);
            expect(addr1Balance).to.equal(amount);
        });

        it('Should revert if the gift is not expired', async function () {
            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('expired@example.com'),
            );
            const amount = ethers.utils.parseEther('10');
            await mockERC20.connect(addr1).approve(tokenTransfer.address, amount);

            await giftManager
                .connect(addr1)
                .depositGift(mockERC20.address, recipientHash, amount, 1);

            // Reclaim the gift
            await expect(giftManager.connect(addr1).reclaimGift(recipientHash)).to.be.revertedWith(
                'GiftNotExpiredYet',
            );
        });
    });

    describe('Direct Token Transfer', function () {
        it('Should allow direct token transfer', async function () {
            const amount = ethers.utils.parseEther('10');
            await mockERC20.connect(deployer).transfer(addr1.address, amount);

            // Approve tokens for transfer
            await mockERC20.connect(addr1).approve(tokenTransfer.address, amount);

            // Direct transfer from addr1 to addr2
            await expect(
                giftManager
                    .connect(addr1)
                    .directTokenTransfer(mockERC20.address, addr2.address, amount),
            ).to.emit(mockERC20, 'Transfer');

            // Verify addr2 balance
            const addr2Balance = await mockERC20.balanceOf(addr2.address);
            expect(addr2Balance).to.equal(amount);
        });
    });
});
