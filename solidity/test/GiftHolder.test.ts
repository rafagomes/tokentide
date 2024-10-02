import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Contract, Signer } from 'ethers';

describe('GiftHolding Contract', function () {
    let giftHolding: Contract;
    let tokenIdentifier: Contract;
    let mockERC20: Contract;
    let mockERC721: Contract;
    let mockERC1155: Contract;
    let owner: Signer;
    let addr1: Signer;
    let addr2: Signer;

    before(async () => {
        [owner, addr1, addr2] = await ethers.getSigners();

        // Deploy the TokenIdentifier contract
        const TokenIdentifier = await ethers.getContractFactory('TokenIdentifier');
        tokenIdentifier = await TokenIdentifier.deploy();
        await tokenIdentifier.deployed();

        // Deploy the GiftHolding contract
        const GiftHolding = await ethers.getContractFactory('GiftHolding');
        giftHolding = await GiftHolding.deploy(tokenIdentifier.address);
        await giftHolding.deployed();

        // Deploy mock ERC20, ERC721, and ERC1155 tokens
        const MockERC20 = await ethers.getContractFactory('MockERC20');
        mockERC20 = await MockERC20.deploy(ethers.utils.parseEther('1000')); // 1000 tokens
        await mockERC20.deployed();

        const MockERC721 = await ethers.getContractFactory('MockERC721');
        mockERC721 = await MockERC721.deploy();
        await mockERC721.deployed();

        const MockERC1155 = await ethers.getContractFactory('MockERC1155');
        mockERC1155 = await MockERC1155.deploy();
        await mockERC1155.deployed();
    });

    describe('Depositing Gifts', function () {
        it('Should deposit ERC20 tokens as a gift', async function () {
            const amount = ethers.utils.parseEther('100'); // 100 tokens

            // Transfer tokens from `owner` to `addr1` first to set up the test environment
            await mockERC20.connect(owner).transfer(addr1.address, amount);

            // Now addr1 should approve giftHolding contract to transfer those tokens
            await mockERC20.connect(addr1).approve(giftHolding.address, amount);

            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient@example.com'),
            );

            await expect(
                giftHolding.connect(addr1).depositGift(mockERC20.address, amount, recipientHash),
            ).to.emit(giftHolding, 'GiftDeposited');

            const gift = await giftHolding.gifts(recipientHash);
            expect(gift.tokenAddress).to.equal(mockERC20.address);
            expect(gift.amountOrTokenId).to.equal(amount);

            const expectedFee = amount.mul(percentageFee).div(100);
            expect(gift.fee).to.equal(expectedFee);
        });

        it('Should deposit ERC721 tokens as a gift', async function () {
            await mockERC721.connect(owner).mint(await owner.getAddress());
            await mockERC721.connect(owner).approve(giftHolding.address, 3);

            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient2@example.com'),
            );

            await expect(giftHolding.depositGift(mockERC721.address, 3, recipientHash)).to.emit(
                giftHolding,
                'GiftDeposited',
            );

            const gift = await giftHolding.gifts(recipientHash);
            expect(gift.tokenAddress).to.equal(mockERC721.address);
            expect(gift.amountOrTokenId).to.equal(3);
            expect(gift.fee).to.equal(nftFee);
        });

        it('Should deposit ERC1155 tokens as a gift', async function () {
            await mockERC1155.connect(owner).mint(await owner.getAddress(), 1, 1);
            await mockERC1155.connect(owner).setApprovalForAll(giftHolding.address, true);

            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient3@example.com'),
            );

            await expect(giftHolding.depositGift(mockERC1155.address, 1, recipientHash)).to.emit(
                giftHolding,
                'GiftDeposited',
            );

            const gift = await giftHolding.gifts(recipientHash);
            expect(gift.tokenAddress).to.equal(mockERC1155.address);
            expect(gift.amountOrTokenId).to.equal(1);
            expect(gift.fee).to.equal(nftFee);
        });
    });

    describe('Claiming Gifts', function () {
        it('Should allow recipient to claim ERC20 tokens', async function () {
            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient@example.com'),
            );

            // Check balances before claim
            const initialBalanceAddr1 = await mockERC20.balanceOf(await addr1.address);
            const initialBalanceGiftHolding = await mockERC20.balanceOf(giftHolding.address);
            await mockERC20.connect(addr1).approve(giftHolding.address, initialBalanceGiftHolding);
            const allowance = await mockERC20.allowance(addr1.address, giftHolding.address);

            await expect(giftHolding.connect(addr1).claimGift(recipientHash, { value: 0 })).to.emit(
                giftHolding,
                'GiftClaimed',
            );

            const finalBalance = await mockERC20.balanceOf(await addr1.getAddress());
            expect(finalBalance.sub(initialBalanceAddr1)).to.equal(ethers.utils.parseEther('97')); // 100 - 3% fee
        });

        it('Should allow recipient to claim ERC1155 tokens', async function () {
            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient3@example.com'),
            );

            await expect(
                giftHolding.connect(addr1).claimGift(recipientHash, { value: nftFee }),
            ).to.emit(giftHolding, 'GiftClaimed');

            expect(await mockERC1155.balanceOf(await addr1.getAddress(), 1)).to.equal(1);
        });
    });

    describe('Negative Test Cases', function () {
        it('Should revert on insufficient ERC20 balance', async function () {
            const insufficientAmount = ethers.utils.parseEther('2000');
            await mockERC20.connect(owner).approve(giftHolding.address, insufficientAmount);
            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('fail1@example.com'),
            );

            await expect(
                giftHolding.depositGift(mockERC20.address, insufficientAmount, recipientHash),
            ).to.be.revertedWith('Insufficient balance');
        });

        it('Should revert if claim is attempted twice or not found', async function () {
            const recipientHash = ethers.utils.keccak256(
                ethers.utils.toUtf8Bytes('recipient@example.com'),
            );

            await expect(
                giftHolding.connect(addr1).claimGift(recipientHash, { value: 0 }),
            ).to.be.revertedWith('No gift found for this email or already claimed');
        });
    });
});
