import {
  type ShieldedContract,
  type ShieldedWalletClient,
  createShieldedWalletClient,
} from "seismic-viem";
import { type Abi, type Address, type Chain, http } from "viem";
import { privateKeyToAccount } from "viem/accounts";

import { getShieldedContractWithCheck } from "../lib/utils";

/**
 * The configuration for the app.
 */
interface AppConfig {
  manager: {
    name: string;
    privateKey: string;
  };
  businesses: Array<{
    name: string;
    privateKey: string;
  }>;
  participants: Array<{
    name: string;
    privateKey: string;
  }>;
  wallet: {
    chain: Chain;
    rpcUrl: string;
  };
  // Competition contract (Chain contract automatically initialized)
  contract: {
    abi: Abi;
    address: Address;
  };
}

/**
 * The main application class.
 */
export class App {
  private config: AppConfig;

  private managerClient: [string, ShieldedWalletClient | null] = ["", null];
  private managerContract: [string, ShieldedContract | null] = ["", null];

  private businessClients: Map<String, ShieldedWalletClient> = new Map();
  private businessContracts: Map<String, ShieldedContract> = new Map();

  private participantClients: Map<String, ShieldedWalletClient> = new Map();
  private participantContracts: Map<String, ShieldedContract> = new Map();

  constructor(config: AppConfig) {
    this.config = config;
  }

  /**
   * Initialize the app.
   */
  async init() {
    /**
     * Setup Manager
     */
    const managerWalletClient = await createShieldedWalletClient({
      chain: this.config.wallet.chain,
      transport: http(this.config.wallet.rpcUrl),
      account: privateKeyToAccount(
        this.config.manager.privateKey as `0x${string}`
      ),
    });
    this.managerClient = [this.config.manager.name, managerWalletClient];

    const managerContract = await getShieldedContractWithCheck(
      managerWalletClient,
      this.config.contract.abi,
      this.config.contract.address
    );
    this.managerContract = [this.config.manager.name, managerContract];

    /**
     * Setup Businesses
     */
    for (const business of this.config.businesses) {
      const walletClient = await createShieldedWalletClient({
        chain: this.config.wallet.chain,
        transport: http(this.config.wallet.rpcUrl),
        account: privateKeyToAccount(business.privateKey as `0x${string}`),
      });
      this.businessClients.set(business.name, walletClient);

      const contract = await getShieldedContractWithCheck(
        walletClient,
        this.config.contract.abi,
        this.config.contract.address
      );
      this.businessContracts.set(business.name, contract);
    }

    /**
     * Setup Participants
     */
    for (const participant of this.config.participants) {
      const walletClient = await createShieldedWalletClient({
        chain: this.config.wallet.chain,
        transport: http(this.config.wallet.rpcUrl),
        account: privateKeyToAccount(participant.privateKey as `0x${string}`),
      });
      this.participantClients.set(participant.name, walletClient);

      const contract = await getShieldedContractWithCheck(
        walletClient,
        this.config.contract.abi,
        this.config.contract.address
      );
      this.participantContracts.set(participant.name, contract);
    }

    /**
     * Setup Competition
     */
    // Approve businesses
    for (const business of this.config.businesses) {
      const account = privateKeyToAccount(business.privateKey as `0x${string}`);
      await managerContract.write.businessApprovalProcess([account.address]);
    }
    // Start competition
    await managerContract.write.startCompetition();
  }

  /**
   * Get the shielded contract for a manager.
   * @param managerName - The name of the manager.
   * @returns The shielded contract for the manager.
   */
  private getManagerContract(managerName: string): ShieldedContract {
    const contract = this.managerContract[1];
    if (!contract) {
      throw new Error(`Shielded contract for manager ${managerName} not found`);
    }
    return contract;
  }

  /**
   * Get the shielded contract for a business.
   * @param businessName - The name of the business.
   * @returns The shielded contract for the business.
   */
  private getBusinessContract(businessName: string): ShieldedContract {
    const contract = this.businessContracts.get(businessName);
    if (!contract) {
      throw new Error(
        `Shielded contract for business ${businessName} not found`
      );
    }
    return contract;
  }

  /**
   * Get the shielded contract for a participant.
   * @param participantName - The name of the participant.
   * @returns The shielded contract for the participant.
   */
  private getParticipantContract(participantName: string): ShieldedContract {
    const contract = this.participantContracts.get(participantName);
    if (!contract) {
      throw new Error(
        `Shielded contract for participant ${participantName} not found`
      );
    }
    return contract;
  }
  /**
   * End the competition.
   * @param managerName - The name of the manager.
   */
  async endCompetition(managerName: string) {
    console.log(`- Manager ${managerName} writing endCompetition()`);
    const contract = this.getManagerContract(managerName);
    await contract.write.endCompetition([]);
  }
}
