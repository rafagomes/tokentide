import { ethers } from 'hardhat';
import { Contract } from 'ethers';
import chai from 'chai';
import { solidity } from 'ethereum-waffle';

chai.use(solidity);
const { expect } = chai;

describe('TokenIdentifier Contract', function () {
    let tokenIdentifier: Contract;
    let mockERC20: Contract, mockERC721: Contract, mockERC1155: Contract;
    let deployer: any;

    before(async () => {
        [deployer] = await ethers.getSigners();

        const TokenIdentifier = await ethers.getContractFactory('TokenIdentifier');
        tokenIdentifier = await TokenIdentifier.deploy();
        await tokenIdentifier.deployed();

        const MockERC20 = await ethers.getContractFactory('MockERC20');
        mockERC20 = await MockERC20.deploy(ethers.utils.parseEther('1000'));
        await mockERC20.deployed();

        const MockERC721 = await ethers.getContractFactory('MockERC721');
        mockERC721 = await MockERC721.deploy();
        await mockERC721.deployed();

        const MockERC1155 = await ethers.getContractFactory('MockERC1155');
        mockERC1155 = await MockERC1155.deploy();
        await mockERC1155.deployed();
    });

    it('Should correctly identify ERC-20 token', async function () {
        const tokenType = await tokenIdentifier.callStatic.identifyTokenType(mockERC20.address);
        expect(tokenType).to.equal(1); // 1 corresponds to ERC20 in the enum
    });

    it('Should correctly identify ERC-721 token', async function () {
        const tokenType = await tokenIdentifier.callStatic.identifyTokenType(mockERC721.address);
        expect(tokenType).to.equal(2); // 2 corresponds to ERC721 in the enum
    });

    it('Should correctly identify ERC-1155 token', async function () {
        const tokenType = await tokenIdentifier.callStatic.identifyTokenType(mockERC1155.address);
        expect(tokenType).to.equal(3); // 3 corresponds to ERC1155 in the enum
    });

    it('Should return UNKNOWN (0) for non-token contracts or incorrect addresses', async function () {
        const tokenType = await tokenIdentifier.callStatic.identifyTokenType(deployer.address);
        expect(tokenType).to.equal(0); // 0 corresponds to UNKNOWN in the enum
    });

    it('Should emit DetectionFailed for an address that is not a contract', async function () {
        await expect(tokenIdentifier.identifyTokenType(deployer.address))
            .to.emit(tokenIdentifier, 'DetectionFailed')
            .withArgs(deployer.address, 'Address is not a contract', deployer.address);
    });
});
