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
3. Obtain a Sepolia RPC endpoint. Open a terminal in the cloned repository and
   set the endpoint. You can start with the default public endpoint:

   ```sh
   cd Escrow
   export SEPOLIA_RPC_URL="https://ethereum-sepolia-rpc.publicnode.com"
   cast chain-id --rpc-url "$SEPOLIA_RPC_URL"
   ```

   **Alternative RPC (if experiencing rate limits or RPC troubles):**
   Public endpoints can occasionally be congested, rate-limited, or unstable. If you run into deployment timeouts or connection issues with the default RPC, obtain a free dedicated Sepolia endpoint from [Alchemy](https://www.alchemy.com/):
   - Sign up at Alchemy and create an app on **Ethereum Sepolia**.
   - Copy your HTTPS URL (format: `https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY`).
   - Set the Alchemy RPC URL:
     ```sh
     export SEPOLIA_RPC_URL="https://eth-sepolia.g.alchemy.com/v2/YOUR_API_KEY"
     ```

   Confirm the chain ID prints `11155111` before deploying:
   ```sh
   cast chain-id --rpc-url "$SEPOLIA_RPC_URL"
   ```
4. Deploy the contracts from that same terminal. `--slow` waits between
   transactions and avoids overwhelming RPCs that limit in-flight requests.
   The Foundry config enables Solidity optimization to reduce the deployed
   contract bytecode size. The gas estimate multiplier provides additional
   headroom for Sepolia's contract code storage cost:

   ```sh
   forge script script/DeployEscrow.s.sol:DeployEscrow \
     --rpc-url "$SEPOLIA_RPC_URL" \
     --broadcast \
     --slow \
     --gas-estimate-multiplier 500
   ```

   The script uses `PRIVATE_KEY` from `.env` for deployment. It prints
   **Escrow deployed at** and the supported token address. Save the escrow
   address only after the broadcast succeeds. On Sepolia, the demo supports
   Sepolia WETH only. Do not deploy this project to Ethereum mainnet.

   **Alternative direct deployment (`forge create`):**
   If `forge script` encounters simulation issues, code storage out-of-gas errors, or RPC timeout issues, you can deploy the contract directly with `forge create`:

   ```sh
   forge create src/Escrow.sol:Escrow \
     --rpc-url "$SEPOLIA_RPC_URL" \
     --private-key "$PRIVATE_KEY" \
     --broadcast \
     --constructor-args "[0xdd13E55209Fd76AfE204dBda4007C227904f0a81]" "[0x694AA1769357215DE4FAC081bf1f309aDC325306]"
   ```
   *(Note: Ensure `--broadcast` comes before `--constructor-args` so Foundry does not consume it as a constructor argument).*

### Troubleshooting Deployment Issues

- **Contract code storage out of gas (`ErrCodeStoreOutOfGas`):**
  Ensure your `foundry.toml` targets the `shanghai` EVM version with the optimizer enabled to prevent Cancun/Prague opcode incompatibilities with Sepolia testnet nodes:
  ```toml
  [profile.default]
  evm_version = "shanghai"
  optimizer = true
  optimizer_runs = 200
  ```
- **EIP-7702 Account Delegation Conflict:**
  If your deployer wallet was previously used in account abstraction experiments, check its bytecode with `cast code $DEPLOYER_ADDRESS --rpc-url "$SEPOLIA_RPC_URL"`. If it returns delegation bytecode (`0xef0100...`), standard top-level contract creation will fail. Revoke delegation before deploying:
  ```sh
  cast send $DEPLOYER_ADDRESS \
    --auth 0x0000000000000000000000000000000000000000 \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$SEPOLIA_RPC_URL"
  ```
5. Verify the escrow address printed by the successful broadcast. Replace the
   placeholder with that address:

   ```sh
   cast code YOUR_ESCROW_ADDRESS --rpc-url "$SEPOLIA_RPC_URL"
   ```

   A deployed contract returns bytecode. If the result is `0x`, the contract
   is not deployed at that address; do not load it in the frontend. Do not rely
   on an address shown only in the simulation summary—use the successful
   broadcast output.

The Sepolia demo supports Sepolia WETH only. This is a test asset with no
real-world value. The frontend reads the token from the loaded escrow contract,
so it appears in the app when you load the contract.

### How to Get Sepolia WETH in MetaMask

The supported WETH token on Sepolia is the canonical Sepolia WETH9 contract:

```text
0xdd13E55209Fd76AfE204dBda4007C227904f0a81
```

This is Sepolia test WETH, not mainnet WETH, and has no real-world value. ETH and WETH are distinct: Sepolia ETH pays gas, while WETH is the ERC-20 token deposited into an escrow.

#### Step 1: Import WETH into MetaMask
1. Open MetaMask and ensure the active network is **Sepolia**.
2. Select the **Tokens** (or Assets) tab and click **Import tokens** at the bottom.
3. Choose **Custom token** and paste the address:
   `0xdd13E55209Fd76AfE204dBda4007C227904f0a81`
4. Token Symbol (`WETH`) and Decimals (`18`) will auto-populate. Click **Next** / **Import**.

#### Step 2: Wrap Sepolia ETH into WETH

You can wrap Sepolia ETH into WETH using any of the following methods:

- **Method A: Direct Send in MetaMask (Fastest in Browser)**
  1. In MetaMask on Sepolia, click **Send**.
  2. Paste the WETH contract address: `0xdd13E55209Fd76AfE204dBda4007C227904f0a81`.
  3. Enter the amount of Sepolia ETH you want to wrap (e.g. `0.02` ETH).
  4. Confirm the transaction. The WETH contract receives the ETH and automatically issues the identical amount of WETH to your account.

- **Method B: Using Foundry `cast` (Fastest in Terminal)**
  Run the deposit function directly from your terminal:
  ```sh
  cast send 0xdd13E55209Fd76AfE204dBda4007C227904f0a81 "deposit()" \
    --value 0.05ether \
    --private-key "$PRIVATE_KEY" \
    --rpc-url "$SEPOLIA_RPC_URL"
  ```

- **Method C: Using Uniswap on Sepolia**
  Visit [app.uniswap.org](https://app.uniswap.org), connect MetaMask on Sepolia, and swap Sepolia ETH for WETH (1:1 with no slippage).

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
- The Sepolia demo supports Sepolia WETH, a test asset with no real-world value.
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
