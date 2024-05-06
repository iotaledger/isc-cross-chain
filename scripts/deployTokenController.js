require('dotenv').config();
const {ethers} = require('hardhat');

// Token Configuration
const config = require('../hardhat.config');

const sandboxABI = require('@iota/iscmagic/ISCSandbox.json');
const iscutilABI = require('@iota/iscmagic/ISCUtil.json');
const nativeTokensABI = require('@iota/iscmagic/ERC20NativeTokens.json')

async function main() {
    const targetChainProvider = new ethers.providers.JsonRpcProvider(config.networks.TargetTestnet.url);
    const sandbox = await ethers.getContractAt(sandboxABI, '0x1074000000000000000000000000000000000000');
    const targetChainSandbox = new ethers.Contract('0x1074000000000000000000000000000000000000', sandboxABI, targetChainProvider);
    const targetChainUtil = new ethers.Contract('0x1074000000000000000000000000000000000000', iscutilABI, targetChainProvider);

    const [deployer, secondAccount] = await ethers.getSigners();
    console.log("Deploying with account:", deployer.address, "on network:",hre.network.name);
    const initialFunding = ethers.utils.parseEther("10");
    // Deploy contract on origin chain
    const NativeTokenController = await ethers.getContractFactory("NativeTokenController");

    const NativeTokenControllerInstance = await NativeTokenController.deploy(
        config.tokenName, config.tokenSymbol, config.tokenDecimals,
        config.tokenMaxSupply, 1000000, {value: initialFunding});
    await NativeTokenControllerInstance.deployed();
    console.log(`Contract deployed at address: ${NativeTokenControllerInstance.address}`);
    console.log(`Foundry created for ${config.tokenName} (${config.tokenSymbol}) with max supply of ${config.tokenMaxSupply} tokens`);
    const receipt = await NativeTokenControllerInstance.deployTransaction.wait();
    const foundryCreatedEvent = receipt.events.find(event => event.event === 'FoundryCreated');
    const serialNum = foundryCreatedEvent.args.serialNum;
    console.log(`Token serial number: ${serialNum}`);

    // Retrieve native token ID
    const nativeTokenID = await sandbox.getNativeTokenID(serialNum);
    console.log(`Native Token ID: ${nativeTokenID}`);
    const erc20registeredEvent = receipt.events.find(event => event.event === 'ERC20NativeTokenRegistered');
    const erc20TokenAddress = erc20registeredEvent.args.erc20Token;
    console.log(`ERC20 Address on Origin chain: ${erc20TokenAddress}`);


    // Register L1 token foundry as ERC20 on target chain
    console.log(`\n1) Register L1 token foundry as ERC20 on Target chain:\n==========================================`);
    const targetChainID = await targetChainSandbox.getChainID();
    console.log(`ISC Target Chain ID: ${targetChainID}`);
    const targetChainAddress = targetChainID.slice(0, 2) + "08" + targetChainID.slice(2,);

    await NativeTokenControllerInstance.registerERC20NativeTokenOnRemoteChain("Wrapped" + config.tokenName, "w" + config.tokenSymbol, config.tokenDecimals, targetChainAddress, 1000000);
    console.log(`Registered new ERC20 token under the name Wrapped${config.tokenName} (w${config.tokenSymbol})`);

    // Sleep 1 second to give the chains time to sync
    await new Promise(resolve => setTimeout(resolve, 1000));

    // call getERC20ExternalNativeTokenAddress from target chain
    const targetChainER20AddressCall = await targetChainSandbox.callView(
        await targetChainUtil.hn("evm"),
        await targetChainUtil.hn("getERC20ExternalNativeTokenAddress"),
        {
            items: [
                {
                    key: ethers.utils.hexlify(ethers.utils.toUtf8Bytes("N")),
                    value: ethers.utils.hexlify(nativeTokenID.toString()),
                },
            ]
        }
    )
    const targetChainER20Address = targetChainER20AddressCall.items[0].value
    console.log(targetChainER20Address)

    // Get ERC20 Token Address on Target Chain
    console.log(`ERC20 Address on Target chain: ${targetChainER20Address}`);

    // Mint tokens
    console.log(`\n2) Mint tokens in foundry:\n==========================================`);
    const mintTxn = await NativeTokenControllerInstance.mintTokens(config.tokenMaxSupply, 1000000);
    const mintReceipt = await mintTxn.wait();

    console.log(`Foundry for ${config.tokenName} (${config.tokenSymbol}) with max supply of ${config.tokenMaxSupply} tokens created`);
    const mintEvent = mintReceipt.events.find(event => event.event === 'NativeTokensMinted');
    const mintedFoundrySN = mintEvent.args.foundrySN;
    const mintedAmt = mintEvent.args.amount;

    console.log(`Minted ${mintedAmt} for foundry ${mintedFoundrySN}`);

    // Transfer within Origin chain
    console.log(`\n3) Transfer within origin chain:\n==========================================`);
    const originChainID = await sandbox.getChainID();
    await NativeTokenControllerInstance.transfer(10, config.targetAddress);
    console.log(`Target address: ${config.targetAddress}`);
    console.log(`Transferred 1 ${config.tokenSymbol} within origin chain ${originChainID}`);

    // Cross chain transfer from origin to Target chain
    console.log(`\n4) Cross chain transfer from origin to target chain:\n==========================================`);

    const erc20Contract = new ethers.Contract(erc20TokenAddress, nativeTokensABI, ethers.provider.getSigner());
    await erc20Contract.approve(NativeTokenControllerInstance.address, 1);

    await NativeTokenControllerInstance.sendCrossChain(
        targetChainAddress,
        config.targetAddress,
        targetChainID,
        1,
        1000000);
    console.log(`Transferred 1 ${config.tokenSymbol} to ${config.targetAddress} on target chain ${targetChainID}\n`);
}

main()
    .then(() => process.exit(0))
    .catch((error) => {
        console.error(error);
        process.exit(1);
    });
