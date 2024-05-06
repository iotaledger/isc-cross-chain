## IOTA Cross Chain Token Demo

This repo demonstrates the following:
1. Creation of a layer 1 (L1) native token foundry
2. Creation of a layer 2 (L2) ERC20 token backed by the L1 foundry
3. Minting tokens on L1 from within L2 via smart contract
4. Transferring native tokens from one L2 account to another on the same chain
5. Transferring native tokens from one L2 account to another L2 account on a different chain

### Setup
1. Install dependencies 
   ```shell
   npm install
   ```
   
2. (optional) Create a wasp [local setup](https://github.com/iotaledger/wasp/tree/develop/tools/local-setup) to get a couple of nodes running locally to test against.

3. Copy `.env.example` to `.env`:
    ```shell
    cp .env.example .env
    ```

4. Edit the `ORIGIN_NODE_URL` and `TARGET_NODE_URL` environment variables in `.env` so that the chain ID in them matches the chain
   IDs for the two chains you created with the wasp local set, or to the two existing chains you want to use. 

5. If you do not have `wasp-cli` installed, go into your cloned `wasp` repo and run

    ```shell
    make install-cli
    ```

6. Create and fund your chains using the commands below. Note that `0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266` is the 
ethereum address of the wallet you want to use to interact on the chain(s). The provided address is a common hardhat 
testing account but feel free to use your own wallet and keys.

    ```shell
    wasp-cli request-funds
    wasp-cli chain deploy --chain=chain-a
    wasp-cli chain deploy --chain=chain-b
    wasp-cli chain deposit 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 base:10000000000 --chain=chain-a
    wasp-cli chain deposit 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 base:10000000000 --chain=chain-b
     ```

    Another set of commands that can help reset the docker environment is below. I like to run these and then follow up with
    the wasp-cli commands above to set up the two chains again:
    
    ```shell
    docker compose down
    docker volume rm wasp-db hornet-nest-db
    docker volume create --name hornet-nest-db
    docker volume create --name wasp-db
    docker-compose up -d
    ```

7. Execute the script
    ```shell
    npx hardhat run scripts/deployTokenController.js --network OriginTestnet
    ```
