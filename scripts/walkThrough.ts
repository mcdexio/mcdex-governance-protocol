const hre = require("hardhat");
const ethers = hre.ethers

import { DeploymentOptions } from './deployer/deployer'
import { readOnlyEnviron } from './deployer/environ'
import { printError } from './deployer/utils'

const ENV: DeploymentOptions = {
    network: hre.network.name,
    artifactDirectory: './artifacts/contracts',
    addressOverride: {
    }
}

async function main(deployer, accounts) {

    const mcb = await deployer.getDeployedContract("MCB")
    const authenticator = await deployer.getDeployedContract("Authenticator")
    const xmcb = await deployer.getDeployedContract("XMCB")
    const vault = await deployer.getDeployedContract("Vault")
    const valueCapture = await deployer.getDeployedContract("ValueCapture")
    const mcbMinter = await deployer.getDeployedContract("MCBMinter")
    const timelock = await deployer.getDeployedContract("Timelock")
    const governor = await deployer.getDeployedContract("FastGovernorAlpha")


}

ethers.getSigners()
    .then(accounts => readOnlyEnviron(ethers, ENV, main, accounts))
    .then(() => process.exit(0))
    .catch(error => {
        printError(error);
        process.exit(1);
    });