import { ethers } from 'hardhat';
import { Contract } from 'ethers';
import chai from 'chai';
import { solidity } from 'ethereum-waffle';

chai.use(solidity);
const { expect } = chai;

describe('TokenTransfer Contract', function () {
  let tokenTransfer: Contract;
  let tokenIdentifier: Contract;
  let mockERC20: Contract, mockERC721: Contract, mockERC1155: Contract;
  let deployer: any, recipient: any;

  before(async () => {
    [deployer, recipient] = await ethers.getSigners();

    // Deploy the TokenIdentifier contract
    const TokenIdentifier = await ethers.getContractFactory('TokenIdentifier');
    tokenIdentifier = await TokenIdentifier.deploy();
    await tokenIdentifier.deployed();

    // Deploy the TokenTransfer contract with the address of TokenIdentifier
    const TokenTransfer = await ethers.getContractFactory('TokenTransfer');
    tokenTransfer = await TokenTransfer.deploy(tokenIdentifier.address);
    await tokenTransfer.deployed();

    // Deploy mock ERC20, ERC721, and ERC1155 tokens
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

  describe('ERC20 Transfers', function () {
    it('Should revert if trying to transfer ERC-20 without sufficient allowance', async function () {
      await expect(
        tokenTransfer.transferToken(
          mockERC20.address,
          recipient.address,
          ethers.utils.parseEther('10'),
        ),
      ).to.be.revertedWith('ERC20 allowance insufficient');
    });

    it('Should transfer ERC-20 tokens successfully with sufficient allowance', async function () {
      const transferAmount = ethers.utils.parseEther('10');
      await mockERC20.connect(deployer).approve(tokenTransfer.address, transferAmount);

      await expect(
        tokenTransfer.transferToken(mockERC20.address, recipient.address, transferAmount),
      ).to.emit(mockERC20, 'Transfer');

      const recipientBalance = await mockERC20.balanceOf(recipient.address);
      expect(recipientBalance).to.equal(transferAmount);
    });
  });

  describe('ERC721 Transfers', function () {
    it('Should revert if trying to transfer ERC-721 without approval', async function () {
      await mockERC721.connect(deployer).mint(deployer.address);

      await expect(
        tokenTransfer.transferToken(mockERC721.address, recipient.address, 1),
      ).to.be.revertedWith('Contract not approved for ERC721 transfer');
    });

    it('Should transfer ERC-721 tokens successfully with approval', async function () {
      await mockERC721.connect(deployer).approve(tokenTransfer.address, 1);

      await expect(tokenTransfer.transferToken(mockERC721.address, recipient.address, 1)).to.emit(
        mockERC721,
        'Transfer',
      );

      expect(await mockERC721.ownerOf(1)).to.equal(recipient.address);
    });
  });

  describe('ERC1155 Transfers', function () {
    it('Should revert if trying to transfer ERC-1155 without approval', async function () {
      await mockERC1155.connect(deployer).mint(deployer.address, 1, 1);

      await expect(
        tokenTransfer.transferToken(mockERC1155.address, recipient.address, 1),
      ).to.be.revertedWith('Contract not approved for ERC1155 transfer');
    });

    it('Should transfer ERC-1155 tokens successfully with approval', async function () {
      await mockERC1155.connect(deployer).setApprovalForAll(tokenTransfer.address, true);

      await expect(tokenTransfer.transferToken(mockERC1155.address, recipient.address, 1)).to.emit(
        mockERC1155,
        'TransferSingle',
      );

      const recipientBalance = await mockERC1155.balanceOf(recipient.address, 1);
      expect(recipientBalance).to.equal(1);
    });
  });

  describe('Negative Cases', function () {
    it('Should revert when trying to transfer an unsupported token type', async function () {
      const invalidTokenAddress = ethers.constants.AddressZero;
      await expect(
        tokenTransfer.transferToken(invalidTokenAddress, recipient.address, 1),
      ).to.be.revertedWith('Unsupported token type');
    });

    it('Should revert if trying to transfer tokens to oneself', async function () {
      await expect(
        tokenTransfer.transferToken(
          mockERC20.address,
          deployer.address,
          ethers.utils.parseEther('1'),
        ),
      ).to.be.revertedWith('Cannot transfer to yourself');
    });
  });
});
