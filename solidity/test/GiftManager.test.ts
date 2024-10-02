import { expect } from 'chai';
import { ethers } from 'hardhat';
import { Contract, Signer } from 'ethers';

describe('GiftManager Contract', function () {
    let giftManager: Contract;
    let tokenIdentifier: Contract;
    let mockERC20: Contract;
    let mockERC721: Contract;
    let mockERC1155: Contract;
    let owner: Signer;
    let addr1: Signer;
    let addr2: Signer;

    const percentageFee = 3; // 3%
    const nftFee = ethers.utils.parseEther('0.005'); // 0.005 ETH

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

    describe('Fee Update', function () {
        it('Should update fees correctly by owner', async function () {
            await giftHolding.updateFees(5, ethers.utils.parseEther('0.01'));
            expect(await giftHolding.percentageFee()).to.equal(5);
            expect(await giftHolding.nftFee()).to.equal(ethers.utils.parseEther('0.01'));
        });

        it('Should revert fee update if not the owner', async function () {
            await expect(
                giftHolding.connect(addr1).updateFees(5, ethers.utils.parseEther('0.01')),
            ).to.be.revertedWith('GiftHolding: Only owner is allowed to call this function');
        });
    });
});
