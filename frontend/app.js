import { ethers } from "https://cdn.jsdelivr.net/npm/ethers@6.13.5/+esm";

const ESCROW_ABI = [
  "function owner() view returns (address)",
  "function escrow_id() view returns (uint256)",
  "function getSupportedTokens() view returns (address[])",
  "function retrieve_(uint256) view returns ((address client,address freelancer,address token,uint256 amount,uint8 status,bool is_initialized))",
  "function createEscrow(address freelancer,address token,uint256 amount)",
  "function releaseFunds(uint256 escrowId)",
  "function cancelEscrow(uint256 escrowId)",
  "function raiseDispute(uint256 escrowId)",
  "function resolveDispute(uint256 escrowId,address winner)",
];

const ERC20_ABI = [
  "function name() view returns (string)",
  "function symbol() view returns (string)",
  "function decimals() view returns (uint8)",
  "function balanceOf(address) view returns (uint256)",
  "function allowance(address,address) view returns (uint256)",
  "function approve(address,uint256) returns (bool)",
];

const STATUS = ["Active", "Disputed", "Completed", "Cancelled"];
const MAX_VISIBLE_ESCROWS = 100n;
const elements = {
  address: document.querySelector("#contract-address"),
  connect: document.querySelector("#connect-wallet"),
  contractForm: document.querySelector("#contract-form"),
  createButton: document.querySelector("#create-escrow"),
  createForm: document.querySelector("#create-form"),
  escrowCount: document.querySelector("#escrow-count"),
  escrowList: document.querySelector("#escrow-list"),
  freelancer: document.querySelector("#freelancer"),
  network: document.querySelector("#network-label"),
  notice: document.querySelector("#notice"),
  refresh: document.querySelector("#refresh-escrows"),
  token: document.querySelector("#token"),
  amount: document.querySelector("#amount"),
};

let provider;
let signer;
let account;
let contract;
let contractAddress;
let owner;
let tokens = [];

const queryAddress = new URLSearchParams(window.location.search).get("contract");
const savedAddress = queryAddress || localStorage.getItem("escrow-contract");
if (savedAddress) elements.address.value = savedAddress;

function showNotice(message, kind = "info") {
  elements.notice.textContent = message;
  elements.notice.className = `notice notice-${kind}`;
  elements.notice.hidden = false;
}

function errorMessage(error) {
  return (
    error?.shortMessage ||
    error?.reason ||
    error?.info?.error?.message ||
    error?.message ||
    "The request failed. Check the wallet and network, then try again."
  );
}

function shortAddress(address) {
  return `${address.slice(0, 6)}…${address.slice(-4)}`;
}

function escapeHtml(value) {
  return String(value).replace(/[&<>"']/g, (character) => {
    const entities = {
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    };
    return entities[character];
  });
}

function setBusy(isBusy) {
  elements.connect.disabled = isBusy;
  elements.createButton.disabled = isBusy || !contract || !account || tokens.length === 0;
  elements.refresh.disabled = isBusy || !contract;
  elements.contractForm.querySelector("button").disabled = isBusy;
  elements.escrowList.querySelectorAll("button").forEach((button) => {
    button.disabled = isBusy;
  });
}

async function connectWallet() {
  if (!window.ethereum) {
    throw new Error("No injected wallet found. Install or open a Web3 wallet.");
  }

  provider = new ethers.BrowserProvider(window.ethereum);
  await provider.send("eth_requestAccounts", []);
  signer = await provider.getSigner();
  account = await signer.getAddress();
  const network = await provider.getNetwork();
  elements.network.textContent = `${network.name === "unknown" ? `Chain ${network.chainId}` : network.name} · ${shortAddress(account)}`;
  elements.connect.textContent = shortAddress(account);

  if (contractAddress) await loadContract(contractAddress);
}

async function loadContract(address) {
  if (!provider || !account) {
    throw new Error("Connect your wallet before loading a contract.");
  }
  if (!ethers.isAddress(address)) {
    throw new Error("Enter a valid contract address.");
  }

  const code = await provider.getCode(address);
  if (code === "0x") {
    throw new Error("No contract code found at that address on the connected network.");
  }

  contractAddress = ethers.getAddress(address);
  const readContract = new ethers.Contract(contractAddress, ESCROW_ABI, provider);
  const [contractOwner, tokenAddresses] = await Promise.all([
    readContract.owner(),
    readContract.getSupportedTokens(),
  ]);

  owner = ethers.getAddress(contractOwner);
  tokens = await Promise.all(
    tokenAddresses.map(async (tokenAddress) => {
      const tokenContract = new ethers.Contract(tokenAddress, ERC20_ABI, provider);
      const [symbol, decimals] = await Promise.all([
        tokenContract.symbol(),
        tokenContract.decimals(),
      ]);
      return {
        address: ethers.getAddress(tokenAddress),
        symbol,
        decimals: Number(decimals),
      };
    }),
  );

  contract = new ethers.Contract(contractAddress, ESCROW_ABI, signer);
  elements.address.value = contractAddress;
  localStorage.setItem("escrow-contract", contractAddress);
  elements.token.replaceChildren(
    ...tokens.map((token) => {
      const option = document.createElement("option");
      option.value = token.address;
      option.textContent = token.symbol;
      return option;
    }),
  );
  elements.token.disabled = tokens.length === 0;
  elements.createButton.disabled = tokens.length === 0;
  elements.refresh.disabled = false;
  showNotice(`Connected to escrow ${shortAddress(contractAddress)}.`, "success");
  await refreshEscrows();
}

function actionButton(action, id, label, extraClass = "") {
  return `<button class="button button-small ${extraClass}" type="button" data-action="${action}" data-id="${id}">${label}</button>`;
}

function actionsFor(escrow, id) {
  const actions = [];
  const isClient = account.toLowerCase() === escrow.client.toLowerCase();
  const isFreelancer = account.toLowerCase() === escrow.freelancer.toLowerCase();
  const isOwner = account.toLowerCase() === owner.toLowerCase();

  if (escrow.status === 0 && isClient) {
    actions.push(actionButton("release", id, "Release funds", "button-accent"));
    actions.push(actionButton("cancel", id, "Cancel"));
  }
  if (escrow.status === 0 && (isClient || isFreelancer)) {
    actions.push(actionButton("dispute", id, "Raise dispute"));
  }
  if (escrow.status === 1 && isOwner) {
    actions.push(actionButton("resolve-client", id, "Refund client"));
    actions.push(actionButton("resolve-freelancer", id, "Pay freelancer", "button-accent"));
  }

  return actions.join("");
}

async function refreshEscrows() {
  if (!contract) return;
  const readContract = new ethers.Contract(contractAddress, ESCROW_ABI, provider);
  const total = await readContract.escrow_id();
  elements.escrowCount.textContent = total.toString();

  if (total === 0n) {
    elements.escrowList.innerHTML = `
      <div class="empty-state">
        <span class="empty-icon">✳</span>
        <h3>No escrows yet.</h3>
        <p>Create an agreement to see it here.</p>
      </div>`;
    return;
  }

  const start = total > MAX_VISIBLE_ESCROWS ? total - MAX_VISIBLE_ESCROWS : 0n;
  const records = [];
  for (let id = total - 1n; id >= start; id -= 1n) {
    const item = await readContract.retrieve_(id);
    const token = tokens.find(
      (supportedToken) => supportedToken.address.toLowerCase() === item.token.toLowerCase(),
    );
    if (!token) {
      throw new Error(`Escrow ${id} uses a token not listed by this contract.`);
    }
    records.push({ id, item, token });
  }

  elements.escrowList.innerHTML = records
    .map(({ id, item, token }) => {
      const status = Number(item.status);
      const amount = ethers.formatUnits(item.amount, token.decimals);
      const detail = item.client.toLowerCase() === account.toLowerCase()
        ? `Freelancer ${shortAddress(item.freelancer)}`
        : item.freelancer.toLowerCase() === account.toLowerCase()
          ? `Client ${shortAddress(item.client)}`
          : `Client ${shortAddress(item.client)} · Freelancer ${shortAddress(item.freelancer)}`;

      return `
        <article class="escrow-card">
          <div class="escrow-card-top">
            <span class="escrow-id">ESCROW #${id}</span>
            <span class="status status-${STATUS[status].toLowerCase()}">${STATUS[status]}</span>
          </div>
          <div class="escrow-main">
            <div>
              <p class="escrow-amount">${escapeHtml(amount)} <span>${escapeHtml(token.symbol)}</span></p>
              <p class="escrow-parties">${escapeHtml(detail)}</p>
            </div>
            <span class="token-mark">${escapeHtml(token.symbol.slice(0, 1))}</span>
          </div>
          <div class="escrow-actions">${actionsFor(
            {
              client: item.client,
              freelancer: item.freelancer,
              status,
            },
            id,
          )}</div>
        </article>`;
    })
    .join("");
}

async function submitCreateEscrow(event) {
  event.preventDefault();
  if (!contract || !account) throw new Error("Connect a wallet and load a contract first.");

  const freelancer = ethers.getAddress(elements.freelancer.value.trim());
  if (freelancer === ethers.ZeroAddress) throw new Error("The freelancer address cannot be zero.");

  const token = tokens.find(
    (supportedToken) => supportedToken.address === ethers.getAddress(elements.token.value),
  );
  if (!token) throw new Error("Select a supported payment token.");

  const amount = ethers.parseUnits(elements.amount.value.trim(), token.decimals);
  if (amount <= 0n) throw new Error("Enter an amount greater than zero.");

  const tokenContract = new ethers.Contract(token.address, ERC20_ABI, signer);
  const balance = await tokenContract.balanceOf(account);
  if (balance < amount) {
    throw new Error(`Insufficient ${token.symbol} balance for this escrow.`);
  }

  const allowance = await tokenContract.allowance(account, contractAddress);
  if (allowance < amount) {
    showNotice(`Approve ${token.symbol} in your wallet to continue.`, "info");
    const approval = await tokenContract.approve(contractAddress, amount);
    showNotice(`Waiting for token approval ${approval.hash}…`, "info");
    await approval.wait();
  }

  showNotice("Confirm the escrow transaction in your wallet.", "info");
  const transaction = await contract.createEscrow(freelancer, token.address, amount);
  showNotice(`Waiting for escrow transaction ${transaction.hash}…`, "info");
  await transaction.wait();
  elements.createForm.reset();
  showNotice("Escrow created successfully.", "success");
  await refreshEscrows();
}

async function runEscrowAction(action, id) {
  const functions = {
    release: () => contract.releaseFunds(id),
    cancel: () => contract.cancelEscrow(id),
    dispute: () => contract.raiseDispute(id),
    "resolve-client": async () => {
      const readContract = new ethers.Contract(contractAddress, ESCROW_ABI, provider);
      const escrow = await readContract.retrieve_(id);
      return contract.resolveDispute(id, escrow.client);
    },
    "resolve-freelancer": async () => {
      const readContract = new ethers.Contract(contractAddress, ESCROW_ABI, provider);
      const escrow = await readContract.retrieve_(id);
      return contract.resolveDispute(id, escrow.freelancer);
    },
  };

  const transaction = await functions[action]();
  showNotice(`Waiting for transaction ${transaction.hash}…`, "info");
  await transaction.wait();
  showNotice("Escrow updated successfully.", "success");
  await refreshEscrows();
}

elements.connect.addEventListener("click", async () => {
  setBusy(true);
  try {
    await connectWallet();
  } catch (error) {
    showNotice(errorMessage(error), "error");
  } finally {
    setBusy(false);
  }
});

elements.contractForm.addEventListener("submit", async (event) => {
  event.preventDefault();
  setBusy(true);
  try {
    await loadContract(elements.address.value.trim());
  } catch (error) {
    showNotice(errorMessage(error), "error");
  } finally {
    setBusy(false);
  }
});

elements.createForm.addEventListener("submit", async (event) => {
  setBusy(true);
  try {
    await submitCreateEscrow(event);
  } catch (error) {
    showNotice(errorMessage(error), "error");
  } finally {
    setBusy(false);
  }
});

elements.refresh.addEventListener("click", async () => {
  setBusy(true);
  try {
    await refreshEscrows();
  } catch (error) {
    showNotice(errorMessage(error), "error");
  } finally {
    setBusy(false);
  }
});

elements.escrowList.addEventListener("click", async (event) => {
  const button = event.target.closest("button[data-action]");
  if (!button) return;

  setBusy(true);
  try {
    await runEscrowAction(button.dataset.action, BigInt(button.dataset.id));
  } catch (error) {
    showNotice(errorMessage(error), "error");
  } finally {
    setBusy(false);
  }
});

if (window.ethereum) {
  window.ethereum.on("accountsChanged", async (accounts) => {
    if (!accounts.length) {
      account = undefined;
      signer = undefined;
      contract = undefined;
      elements.network.textContent = "Wallet disconnected";
      elements.connect.textContent = "Connect wallet";
      elements.createButton.disabled = true;
      elements.refresh.disabled = true;
      showNotice("Wallet disconnected.", "info");
      return;
    }
    try {
      provider = new ethers.BrowserProvider(window.ethereum);
      signer = await provider.getSigner();
      account = await signer.getAddress();
      const network = await provider.getNetwork();
      elements.network.textContent = `${network.name === "unknown" ? `Chain ${network.chainId}` : network.name} · ${shortAddress(account)}`;
      elements.connect.textContent = shortAddress(account);
      if (contractAddress) await loadContract(contractAddress);
    } catch (error) {
      showNotice(errorMessage(error), "error");
    }
  });

  window.ethereum.on("chainChanged", () => window.location.reload());
}
