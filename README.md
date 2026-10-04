# Escrow

**Personal learning project — Sepolia testnet demo only.**

This is a small, experimental ERC-20 escrow project for learning and portfolio
use. It is not audited, is not production-ready, and is not intended for
mainnet or real funds. Use testnet accounts and test ETH only.

Clients can deposit an allowed token into an escrow. The client can release or
cancel an active escrow; either party can raise a dispute, which only the
contract owner can resolve.

## Requirements

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- MetaMask (or another injected browser wallet)
- A Sepolia RPC endpoint
- Sepolia test ETH for deployment and transactions

## Clone and prepare the project

Clone the repository including its Foundry dependencies (submodules):

```sh
git clone --recurse-submodules https://github.com/0ste8901/Escrow.git
cd Escrow
```

If you already cloned without submodules, initialize them:

```sh
git submodule update --init --recursive
```

Install Foundry if needed by following its
[installation guide](https://book.getfoundry.sh/getting-started/installation),
then check the project:

```sh
forge --version
forge build
forge test
```

You do not need to run Anvil for the Sepolia demo.

## Deploy the Sepolia demo

MetaMask is the wallet; Sepolia is the network. This project’s recommended
demo uses Sepolia, so the browser wallet and deployed contract must both be on
Sepolia (chain ID `11155111`).

1. In MetaMask, select **Sepolia** and request test ETH from a Sepolia faucet.
   Test ETH has no mainnet value.
2. Create a separate test-only deployer account. Do not use a mainnet wallet’s
   private key. Put its private key in the repository-root `.env` file:

   ```dotenv
   PRIVATE_KEY=0xYOUR_SEPOLIA_TEST_ACCOUNT_PRIVATE_KEY
   ```

   Create the file from the repository root with an editor, or run
   `nano .env` and add that line. `.env` is ignored by Git. Never commit it or
   paste the key into the frontend.
3. Obtain a Sepolia RPC endpoint from an RPC provider. Open a terminal in the
   cloned repository and set the endpoint. The following public endpoint was
   used for this demo; public endpoints may be rate-limited, so you can replace
   it with your own provider URL:

   ```sh
   cd Escrow
   export SEPOLIA_RPC_URL="https://ethereum-sepolia-rpc.publicnode.com"
   cast chain-id --rpc-url "$SEPOLIA_RPC_URL"
   ```

   Confirm the chain ID prints `11155111` before deploying.
4. Deploy the contracts from that same terminal. `--slow` waits between
   transactions and avoids overwhelming RPCs that limit in-flight requests:

   ```sh
   forge script script/DeployEscrow.s.sol:DeployEscrow \
     --rpc-url "$SEPOLIA_RPC_URL" \
     --broadcast \
     --slow
   ```

   The script uses `PRIVATE_KEY` from `.env` for deployment. It prints
   **Escrow deployed at** and both supported token addresses. Save those
   addresses; each deployment has new addresses. The second token is a test-only
   mock token. Do not deploy this project to Ethereum mainnet.
5. Verify the escrow address printed by the successful broadcast. Replace the
   placeholder with that address:

   ```sh
   cast code YOUR_ESCROW_ADDRESS --rpc-url "$SEPOLIA_RPC_URL"
   ```

   A deployed contract returns bytecode. If the result is `0x`, the contract
   is not deployed at that address; do not load it in the frontend. Do not rely
   on an address shown only in the simulation summary—use the successful
   broadcast output.

The Sepolia config uses Sepolia WETH and deploys a mock ERC-20 as the second
demo token. The mock is not backed by BTC or real value. To mint mock tokens
to your MetaMask account for testing, run these commands from the repository
root in a terminal where `SEPOLIA_RPC_URL` is set. Replace both address
placeholders with the mock token address printed by deployment and your
MetaMask account address:

```sh
set -a
source .env
set +a
cast send MOCK_TOKEN_ADDRESS \
  "mint(address,uint256)" METAMASK_ACCOUNT_ADDRESS 100000000000000000000 \
  --rpc-url "$SEPOLIA_RPC_URL" \
  --private-key "$PRIVATE_KEY"
```

This mints 100 mock tokens (18 decimals) to the specified Sepolia address.
Only use the test deployer key for this demo.

### WETH in MetaMask

The supported WETH token on Sepolia is:

```text
0xdd13E55209Fd76AfE204dBda4007C227904f0a81
```

This is Sepolia test WETH, not mainnet WETH, and it has no real-world value.
The frontend reads the token from the loaded escrow contract, so you can
select it in the app without importing it into MetaMask. To see its token
balance in MetaMask, switch MetaMask to **Sepolia**, open **Import tokens**,
choose **Custom token** if prompted, paste the address above, and confirm.

ETH and WETH are distinct: Sepolia ETH pays network gas, while WETH is the ERC-20
token deposited into an escrow. To create a WETH escrow, the connected MetaMask
account needs Sepolia WETH. Obtain test WETH by wrapping Sepolia test ETH using
a trusted Sepolia-compatible WETH interface or faucet; do not use a mainnet
wrapping site or send mainnet funds.

## Start the frontend

Keep the deployment terminal available for its printed addresses. Open a
second terminal, go to the cloned repository, and start the static frontend:

```sh
cd Escrow
python3 -m http.server 8080 --directory frontend
```

Open <http://localhost:8080>, select Sepolia in MetaMask, click **Connect
wallet**, then paste the **Escrow deployed at** address printed by the deploy
command and click **Load**. The wallet account can be different from the
deployer account. Only the deployer/contract owner can resolve disputes.

The address is saved only in that browser’s local storage. The app reads
supported tokens and escrows from the connected network. Creating an escrow
prompts for token approval if needed, then prompts for the escrow transaction.
Clients can release or cancel active escrows; clients and freelancers can
raise disputes; the owner can resolve disputes in favor of either party.

If MetaMask is on a different network from the deployment, switch it to
Sepolia and load the address again. A contract address from Anvil or another
network will not work on Sepolia.

## Scope and limitations

- This is a personal mini deployment for testing on Sepolia, not a mainnet
  launch or production escrow service.
- The escrow contract stores price-feed addresses, but does not currently read
  prices from them.
- Sepolia WETH and the demo mock token are test assets; the mock token has no
  real value.
- The frontend loads ethers.js from jsDelivr and fonts from Google Fonts, so
  those external services must be reachable in the browser.
- Never use a real-funds wallet or reuse its private key for this demo.

## Publish this project to GitHub

To publish under the username `0ste8901`, first create an empty repository on
GitHub:

1. Sign in to GitHub and open <https://github.com/new>.
2. Set the repository name to **Escrow**. Choose **Public** if you want anyone
   to be able to clone it; choose **Private** otherwise.
3. Do not initialize it with a README, `.gitignore`, or license—the project
   already has its own files and local Git history.
4. From the project directory, check that the `.env` file is ignored and review
   the files that will be published:

   ```sh
   cd Escrow
   git status --short
   git check-ignore -v .env
   ```

   Never stage or upload `.env`, private keys, RPC-provider secrets, or files
   from `cache/` or `broadcast/`. The repository ignore rules exclude these.
   Do not use `git add .` until you have reviewed `git status`.
5. Stage the project files and inspect the staged changes:

   ```sh
   git add .gitignore README.md foundry.toml .github frontend script src test
   git status --short
   git diff --cached --check
   git diff --cached --stat
   ```

   Confirm the output lists the intended project files and no `.env`,
   `cache/`, `broadcast/`, or unrelated `wget-log` file.
6. Commit and push the existing local branch:

   ```sh
   git commit -m "Complete escrow demo with frontend"
   git remote add origin https://github.com/0ste8901/Escrow.git
   git push -u origin HEAD
   ```

   If `origin` already exists, inspect it with `git remote -v` and update it
   with `git remote set-url origin https://github.com/0ste8901/Escrow.git`
   instead of adding it again. GitHub may prompt you to authenticate in a
   browser or with GitHub CLI.

After the push, visit <https://github.com/0ste8901/Escrow> to confirm the
files are there. Anyone cloning the project can follow the clone, build, and
test instructions above. Each user must provide their own Sepolia RPC URL,
test-only deployer key, and Sepolia test ETH to deploy their own instance.
