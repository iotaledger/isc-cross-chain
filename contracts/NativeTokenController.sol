// Copyright 2024 IOTA Stiftung
// SPDX-License-Identifier: Apache-2.0

pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@iota/iscmagic/ISC.sol";
import "@iota/iscmagic/ISCTypes.sol";
import "@iota/iscmagic/ISCAccounts.sol";
import "@iota/iscmagic/ISCSandbox.sol";
import "@iota/iscmagic/ERC20NativeTokens.sol";

/**
 * @title Native Token Controller
 * @dev Contract to manage foundries and native tokens in IOTA Smart Contracts.
 * @notice This contract allows for the creation, minting, and management of native tokens using IOTA's ISCMagic framework.
 */
contract NativeTokenController is Ownable {

    /**
     * @dev Emitted when a new foundry is created.
     * @param serialNum Serial number of the created foundry.
     */
    event FoundryCreated(uint32 serialNum);

    /**
     * @dev Emitted when an ERC20 wrapper for a native token is registered.
     * @param name Name of the ERC20 token.
     * @param symbol Symbol of the ERC20 token.
     * @param decimals Number of decimals the ERC20 token uses.
     * @param foundrySN Foundry serial number for the native token.
     * @param erc20Token Address of the ERC20 token contract.
     */
    event ERC20NativeTokenRegistered(
        string name,
        string symbol,
        uint8 decimals,
        uint32 foundrySN,
        address erc20Token
    );

    /**
     * @dev Emitted when native tokens are minted.
     * @param amount Amount of native tokens minted.
     */
    event NativeTokensMinted(uint256 amount);

    uint32 public foundrySN;

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     * @dev Creates a new native tokens foundry with a specified maximum supply.
     * @param name Name of the ERC20 token.
     * @param symbol Symbol of the ERC20 token.
     * @param decimals Number of decimals the ERC20 token uses.
     * @param maxSupply Maximum supply of the native tokens.
     * @param storageDeposit Amount of base tokens to cover storage deposit.
     */
    constructor(string memory name,
        string memory symbol,
        uint8 decimals,
        uint256 maxSupply,
        uint64 storageDeposit) payable Ownable(msg.sender) {
        require(
            address(this).balance > 0,
            "contract requires base tokens for storage deposits"
        );

        NativeTokenScheme memory tokenScheme;
        tokenScheme.maximumSupply = maxSupply;
        foundrySN = ISC.accounts.createNativeTokenFoundry(
            name,
            symbol,
            decimals,
            tokenScheme,
            makeAllowanceBaseTokens(storageDeposit)
        );
        emit FoundryCreated(foundrySN);

        address tokenAddress = ISC.sandbox.erc20NativeTokensAddress(foundrySN);

        emit ERC20NativeTokenRegistered(
            name,
            symbol,
            decimals,
            foundrySN,
            tokenAddress
        );
    }

    /**
     * @dev Sends native tokens from the L1 native token to the L2 EVM account specified.
     * @param chainAddress The L1 address of the destination chain.
     * @param _destination The address on the destination chain that will receive the tokens.
     * @param _chainID Chain ID of the destination chain.
     * @param _amount Amount of native tokens to send.
     * @param _storageDeposit Amount of base tokens to cover storage deposit.
     */
    function sendCrossChain(
        bytes memory chainAddress,
        address _destination,
        ISCChainID _chainID,
        uint256 _amount,
        uint64 _storageDeposit
    ) public payable onlyOwner {
        L1Address memory l1Address = L1Address({data: chainAddress});
        ISCAssets memory metadataAssets = makeAllowanceBaseTokens(0);

        metadataAssets.nativeTokens = new NativeToken[](1);
        metadataAssets.nativeTokens[0] = NativeToken(
            __iscSandbox.getNativeTokenID(foundrySN),
            _amount
        );

        ISCAssets memory sendAssets = makeAllowanceBaseTokens(_storageDeposit);
        sendAssets.nativeTokens = new NativeToken[](1);
        sendAssets.nativeTokens[0] = NativeToken(
            __iscSandbox.getNativeTokenID(foundrySN),
            _amount
        );
        ISCAgentID memory agentID = newEthereumAgentID(_destination, _chainID);

        ISCDict memory params = ISCDict(new ISCDictItem[](1));
        params.items[0] = ISCDictItem("a", agentID.data);

        ISCSendMetadata memory metadata = ISCSendMetadata({
            targetContract: ISC.util.hn("accounts"),
            entrypoint: ISC.util.hn("transferAllowanceTo"),
            params: params,
            allowance: metadataAssets,
            gasBudget: 0xFFFFFFFFFFFFFFFF // Max uint64
        });

        ISCSendOptions memory options = ISCSendOptions({
            timelock: 0,
            expiration: ISCExpiration({
            time: 0,
            returnAddress: L1Address({data: new bytes(0)})
        })
        });

        ISC.sandbox.send(l1Address, sendAssets, false, metadata, options);
    }

    /**
     * @dev Creates a new Ethereum Agent ID.
     * @param addr Ethereum address to include in the agent ID.
     * @param iscChainID Chain ID to include in the agent ID.
     * @return A new ISCAgentID structure containing the Ethereum address and chain ID.
     */
    function newEthereumAgentID(address addr, ISCChainID iscChainID)
    internal
    pure
    returns (ISCAgentID memory)
    {
        bytes memory chainIDBytes = abi.encodePacked(iscChainID);
        bytes memory addrBytes = abi.encodePacked(addr);
        ISCAgentID memory r;
        r.data = new bytes(1 + addrBytes.length + chainIDBytes.length);
        r.data[0] = bytes1(ISCAgentIDKindEthereumAddress);

        // Write chainID
        for (uint256 i = 0; i < chainIDBytes.length; i++) {
            r.data[i + 1] = chainIDBytes[i];
        }

        // Write Ethereum address
        for (uint256 i = 0; i < addrBytes.length; i++) {
            r.data[i + 1 + chainIDBytes.length] = addrBytes[i];
        }
        return r;
    }

    /**
     * @dev Mints native tokens.
     * @param _amount Amount of native tokens to mint.
     * @param _storageDeposit Amount of base tokens to cover storage deposit.
     */
    function mintTokens(
        uint256 _amount,
        uint64 _storageDeposit
    ) public payable onlyOwner {
        ISCAssets memory allowanceBaseTokens;
        allowanceBaseTokens.baseTokens = _storageDeposit;
        ISC.accounts.mintNativeTokens(foundrySN, _amount, allowanceBaseTokens);
        emit NativeTokensMinted(_amount);
    }

    /**
     * @dev Transfers native tokens to a specified address.
     * @param _amount Amount of native tokens to transfer.
     * @param _destination Address to receive the tokens.
     * @return A boolean value indicating whether the transfer was successful.
     */
    function transfer(
        uint256 _amount,
        address _destination
    ) public payable onlyOwner returns (bool) {
        ERC20NativeTokens token = ERC20NativeTokens(
            ISC.sandbox.erc20NativeTokensAddress(foundrySN)
        );
        return token.transfer(_destination, _amount);
    }

    /**
     * @dev Registers an ERC20 wrapper for a native token on a remote chain.
     * @param _name Name of the ERC20 token.
     * @param _symbol Symbol of the ERC20 token.
     * @param _decimals Number of decimals the ERC20 token uses.
     * @param _chainID Chain ID of the remote chain.
     * @param _storageDeposit Amount of base tokens to cover storage deposit.
     */
    function registerERC20NativeTokenOnRemoteChain(
        string calldata _name,
        string calldata _symbol,
        uint8 _decimals,
        bytes memory _chainID,
        uint64 _storageDeposit
    ) public payable onlyOwner {
        require(
            address(this).balance > 0,
            "contract requires base tokens for storage deposits"
        );

        ISCDict memory params = ISCDict(new ISCDictItem[](5));
        params.items[0] = ISCDictItem(
            "fs",
            encodeUint32LittleEndian(foundrySN)
        );
        params.items[1] = ISCDictItem("n", bytes(_name));
        params.items[2] = ISCDictItem("t", bytes(_symbol));
        params.items[3] = ISCDictItem("d", encodeUint8LittleEndian(_decimals));
        params.items[4] = ISCDictItem("A", _chainID);

        ISC.sandbox.call(
            ISC.util.hn("evm"),
            ISC.util.hn("registerERC20NativeTokenOnRemoteChain"),
            params,
            makeAllowanceBaseTokens(_storageDeposit)
        );
    }

    /**
     * @dev Converts bytes to an Ethereum address.
     * @param b Bytes to convert.
     * @return The Ethereum address.
     */
    function bytesToAddress(bytes memory b) public pure returns (address) {
        require(b.length == 20, "Bytes length must be exactly 20");

        address addr;
        // Use assembly to convert from bytes to address
        assembly {
            addr := mload(add(b, 0x14)) // Load the 20 bytes at offset 20 of the input into addr
        }
        return addr;
    }

    /**
     * @dev Creates an allowance for base tokens.
     * @param amount Amount of base tokens to allow.
     * @return A new ISCAssets structure containing the allowance.
     */
    function makeAllowanceBaseTokens(uint64 amount)
    internal
    pure
    returns (ISCAssets memory)
    {
        return ISCAssets({
            baseTokens: amount,
            nativeTokens: new NativeToken[](0),
            nfts: new NFTID[](0)
        });
    }

    /**
     * @dev Encodes a uint32 value in little-endian format.
     * @param value The value to encode.
     * @return The encoded bytes.
     */
    function encodeUint32LittleEndian(uint32 value)
    internal
    pure
    returns (bytes memory)
    {
        bytes memory b = new bytes(4);
        for (uint256 i = 0; i < 4; i++) {
            b[i] = bytes1(uint8(value >> (i * 8)));
        }
        return b;
    }

    /**
     * @dev Encodes a uint8 value in little-endian format.
     * @param value The value to encode.
     * @return The encoded bytes.
     */
    function encodeUint8LittleEndian(uint8 value)
    internal
    pure
    returns (bytes memory)
    {
        bytes memory b = new bytes(1);
        b[0] = bytes1(value);
        return b;
    }

    /**
     * @dev Allows the contract to receive base tokens.
     */
    receive() external payable {}

    /**
     * @dev Withdraws all base tokens from the contract to the owner's address.
     */
    function withdraw() public onlyOwner {
        address payable to = payable(msg.sender);
        to.transfer(address(this).balance);
    }
}
