import dotenv from "dotenv";
import { join } from "path";
import { sanvil, seismicDevnet } from "seismic-viem";

import { CONTRACT_DIR, CONTRACT_NAME } from "../lib/constants";
import { readContractABI, readContractAddress } from "../lib/utils";
import { App } from "./app";

dotenv.config();

async function main() {
  if (!process.env.CHAIN_ID || !process.env.RPC_URL) {
    console.error("Please set your environment variables.");
    process.exit(1);
  }

  const broadcastFile = join(
    CONTRACT_DIR,
    "broadcast",
    `${CONTRACT_NAME}.s.sol`,
    process.env.CHAIN_ID,
    "run-latest.json"
  );
  const abiFile = join(
    CONTRACT_DIR,
    "out",
    `${CONTRACT_NAME}.sol`,
    `${CONTRACT_NAME}.json`
  );

  const chain =
    process.env.CHAIN_ID === sanvil.id.toString() ? sanvil : seismicDevnet;

  const manager = { name: "Gabe", privateKey: process.env.MANAGER_PRIVKEY! };

  const businesses = [
    { name: "Campus Store", privateKey: process.env.BUSINESS_PRIVKEY! },
  ];

  const participants = [
    { name: "Alice", privateKey: process.env.CUSTOMER_PRIVKEY! },
  ];

  const app = new App({
    manager,
    businesses,
    participants,
    wallet: {
      chain,
      rpcUrl: process.env.RPC_URL!,
    },
    contract: {
      abi: readContractABI(abiFile),
      address: readContractAddress(broadcastFile),
    },
  });

  await app.init();

  // Simulating multiplayer interactions
  console.log("=== Competition Start ===");
  await app.endCompetition("Gabe");
}

main();
